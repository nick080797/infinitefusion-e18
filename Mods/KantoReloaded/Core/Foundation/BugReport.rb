#==============================================================================
# Kanto Reloaded Bug Report Workflow
#==============================================================================

begin
  require "net/http"
  require "uri"
rescue LoadError, StandardError
end

module KantoReloaded
  module BugReport
    PASTE_URL = "https://paste.rs/"
    BUG_REPORT_THREAD_URL = "https://discord.com/channels/1121345297352753243/1529078153786429552/1529078153786429552"
    MAX_REPORT_BYTES = 5 * 1024 * 1024
    NETWORK_TIMEOUT_SECONDS = 8

    class << self
      def file
        outcome = run_export(
          nil,
          :title => _INTL("Exporting Bug Report"),
          :initial_message => _INTL("Preparing bug report..."),
          :cancel_prompt => _INTL("Cancel the bug report export?")
        )
        return false unless outcome
        if outcome[:cancelled]
          KantoReloaded.toast_warning(_INTL("Bug report export cancelled."))
          return false
        end
        return handle_failure(outcome) unless outcome[:success]
        handle_success(outcome)
      rescue StandardError => e
        log_exception("File bug report failed", e)
        KantoReloaded.message(
          _INTL("Could not file the bug report.\n{1}", sanitized_error(e)),
          :theme => :error
        )
        false
      end

      def publish_generated(options = {}, &builder)
        raise ArgumentError, "A report builder is required." unless builder
        config = {
          :display_name => _INTL("report"),
          :link_label => "Report",
          :title => _INTL("Exporting Report"),
          :initial_message => _INTL("Preparing report..."),
          :cancel_prompt => _INTL("Cancel the report export?"),
          :open_discord => true
        }.merge(options || {})
        worker = proc do |callback|
          perform_generated_export(config, builder, callback)
        end
        outcome = run_export(worker, config)
        return false unless outcome
        if outcome[:cancelled]
          KantoReloaded.toast_warning(
            _INTL("{1} export cancelled.", display_name(config))
          )
          return false
        end
        return handle_generated_failure(outcome, config) unless outcome[:success]
        handle_generated_success(outcome, config)
      rescue StandardError => e
        log_exception("Generated report publish failed", e)
        KantoReloaded.message(
          _INTL(
            "Could not publish the {1}.\n{2}",
            display_name(options || {}),
            sanitized_error(e)
          ),
          :theme => :error
        )
        false
      end

      def open_discord
        if platform_open_url(BUG_REPORT_THREAD_URL)
          KantoReloaded.toast_success(_INTL("Opened the Kanto Reloaded Discord thread."))
          return true
        end
        KantoReloaded.toast_warning(_INTL("The Kanto Reloaded Discord thread could not be opened."))
        false
      rescue StandardError => e
        log_exception("Open Discord thread failed", e)
        KantoReloaded.toast_warning(_INTL("The Kanto Reloaded Discord thread could not be opened."))
        false
      end

      def install
        KantoReloaded::Log.info("Bug report service ready", :framework) if defined?(KantoReloaded::Log)
        true
      end

      private

      def run_export(worker = nil, progress_options = {})
        worker ||= proc { |callback| perform_export(&callback) }
        if progress_ui_available? && defined?(Thread)
          return KantoReloaded::UI::Modal.with_modal do
            ExportProgressScene.new(worker, progress_options).main
          end
        end
        worker.call(nil)
      ensure
        KantoReloaded::UI::Modal.drain_input if defined?(KantoReloaded::UI::Modal)
      end

      def perform_export
        report_path = nil
        report_url = nil
        log_path = nil
        yield(_INTL("Creating sanitized report...")) if block_given?
        report_path = KantoReloaded::Log.export_bug_report
        validate_report_file(report_path, "LatestBugReport.txt")
        text = File.open(report_path, "rb") { |file| file.read }
        yield(_INTL("Uploading sanitized report...")) if block_given?
        report_url = upload_to_paste(text)
        log_path = KantoReloaded::Log::MAIN_LOG
        validate_report_file(log_path, "Log.txt")
        log_text = File.open(log_path, "rb") { |file| file.read }
        yield(_INTL("Uploading sanitized full log...")) if block_given?
        log_url = upload_to_paste(log_text)
        {
          :success => true,
          :path => report_path,
          :log_path => log_path,
          :url => report_url,
          :log_url => log_url
        }
      rescue StandardError => e
        {
          :success => false,
          :path => report_path,
          :log_path => log_path,
          :url => report_url,
          :error => e
        }
      end

      def perform_generated_export(config, builder, callback = nil)
        report_path = nil
        name = display_name(config)
        callback.call(_INTL("Creating sanitized {1}...", name)) if callback
        report_path = builder.call
        validate_report_file(report_path, name)
        text = File.open(report_path, "rb") { |file| file.read }
        callback.call(_INTL("Uploading sanitized {1}...", name)) if callback
        {
          :success => true,
          :path => report_path,
          :url => upload_to_paste(text)
        }
      rescue StandardError => e
        {
          :success => false,
          :path => report_path,
          :error => e
        }
      end

      def validate_report_file(path, name)
        raise "#{name} could not be created." unless path && File.file?(path)
        raise "#{name} is empty." if File.size(path).to_i <= 0
        raise "#{name} is too large to upload." if File.size(path).to_i > MAX_REPORT_BYTES
        text = File.open(path, "rb") { |file| file.read }
        raise "#{name} is not a text file." if text.include?("\0")
        true
      end

      def upload_to_paste(text)
        content = KantoReloaded::Log.sanitize(text)
        return upload_with_httplite(content) if defined?(HTTPLite)
        return upload_with_net_http(content) if defined?(Net::HTTP) && defined?(URI)
        raise "No HTTP upload backend is available in this runtime."
      end

      def upload_with_httplite(content)
        # See Data/Scripts/001_Technical/002_Files/003_HTTP_Utilities.rb for
        # why every HTTPLite.* call site needs this guard - this one was
        # missing it (and additionally runs off the main thread via
        # BugReport's own @thread, compounding the same native GVL race).
        guarded_call = proc {
          HTTPLite.post_body(
            PASTE_URL,
            content,
            "text/plain",
            {
              "User-Agent" => "KantoReloaded/#{KantoReloaded.version}",
              "Content-Length" => content.bytesize.to_s
            }
          )
        }
        response = respond_to?(:http_call_gc_guard, true) ? http_call_gc_guard(&guarded_call) : guarded_call.call
        status = response.is_a?(Hash) ? (response[:status] || response["status"]).to_i : 0
        raise "Paste upload failed with HTTP #{status}." unless [200, 201, 206].include?(status)
        body = response[:body] || response["body"]
        validate_url(body)
      end

      def upload_with_net_http(content)
        uri = URI.parse(PASTE_URL)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "text/plain; charset=utf-8"
        request["User-Agent"] = "KantoReloaded/#{KantoReloaded.version}"
        request.body = content
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          :use_ssl => uri.scheme == "https",
          :open_timeout => NETWORK_TIMEOUT_SECONDS,
          :read_timeout => NETWORK_TIMEOUT_SECONDS
        ) { |http| http.request(request) }
        code = response.code.to_i
        raise "Paste upload failed with HTTP #{response.code}." unless code >= 200 && code < 300
        validate_url(response.body)
      end

      def validate_url(value)
        url = value.to_s.strip
        raise "Paste upload did not return a URL." unless url =~ /\Ahttps?:\/\/[^\s]+\z/i
        url
      end

      def handle_success(outcome)
        url = outcome[:url].to_s
        log_url = outcome[:log_url].to_s
        links = if joiplay?
                  _INTL("Bug Report: {1}\nFull Log: {2}", url, log_url)
                else
                  "[Bug Report](#{url})\n[Full Log](#{log_url})"
                end
        copied = platform_clipboard_write(links)
        opened = platform_open_url(BUG_REPORT_THREAD_URL)
        if copied && opened
          KantoReloaded.toast_success(
            _INTL("Bug report and log links copied. Discord thread opened.")
          )
        elsif copied
          KantoReloaded.toast_warning(
            _INTL("Bug report and log links copied, but Discord could not be opened.")
          )
        elsif opened
          KantoReloaded.toast_warning(
            _INTL(
              "Discord opened, but the report links could not be copied.\n{1}",
              links
            )
          )
        else
          KantoReloaded.message(
            _INTL(
              "Bug report and log uploaded, but clipboard and Discord are unavailable.\n{1}",
              links
            ),
            :theme => :warning
          )
        end
        true
      end

      def handle_failure(outcome)
        error = outcome[:error]
        path = outcome[:path]
        report_url = outcome[:url].to_s
        unless report_url.empty?
          KantoReloaded.message(
            _INTL(
              "LatestBugReport.txt was uploaded, but Log.txt could not be uploaded.\n{1}\n{2}",
              report_url,
              sanitized_error(error)
            ),
            :theme => :warning
          )
          return false
        end
        if path && File.file?(path)
          KantoReloaded.message(
            _INTL(
              "LatestBugReport.txt was created, but it could not be uploaded.\n{1}\n{2}",
              display_path(path),
              sanitized_error(error)
            ),
            :theme => :warning
          )
        else
          KantoReloaded.message(
            _INTL("Could not create the bug report.\n{1}", sanitized_error(error)),
            :theme => :error
          )
        end
        false
      end

      def handle_generated_success(outcome, config)
        url = outcome[:url].to_s
        link = joiplay? ? url : "[#{config[:link_label]}](#{url})"
        copied = platform_clipboard_write(link)
        open_requested = !!config[:open_discord]
        opened = open_requested && platform_open_url(BUG_REPORT_THREAD_URL)
        name = display_name(config)
        if copied && opened
          KantoReloaded.toast_success(
            _INTL("{1} link copied. Discord thread opened.", name)
          )
        elsif copied && !open_requested
          KantoReloaded.toast_success(
            _INTL("{1} link copied.", name)
          )
        elsif copied
          KantoReloaded.toast_warning(
            _INTL("{1} link copied, but Discord could not be opened.", name)
          )
        elsif opened
          KantoReloaded.toast_warning(
            _INTL("Discord opened, but the {1} link could not be copied.\n{2}", name, url)
          )
        else
          KantoReloaded.message(
            open_requested ?
              _INTL(
                "{1} uploaded, but clipboard and Discord are unavailable.\n{2}",
                name, url
              ) :
              _INTL(
                "{1} uploaded, but the clipboard is unavailable.\n{2}",
                name, url
              ),
            :theme => :warning
          )
        end
        true
      end

      def handle_generated_failure(outcome, config)
        error = outcome[:error]
        path = outcome[:path]
        name = display_name(config)
        if path && File.file?(path)
          KantoReloaded.message(
            _INTL(
              "{1} was created, but it could not be uploaded.\n{2}\n{3}",
              name, display_path(path), sanitized_error(error)
            ),
            :theme => :warning
          )
        else
          KantoReloaded.message(
            _INTL("Could not create the {1}.\n{2}", name, sanitized_error(error)),
            :theme => :error
          )
        end
        false
      end

      def display_name(config)
        value = config.is_a?(Hash) ? config[:display_name] : nil
        value = _INTL("report") if value.nil? || value.to_s.empty?
        value.to_s
      rescue
        "report"
      end

      def platform_clipboard_write(text)
        return false unless defined?(KantoReloaded::Platform)
        return false unless KantoReloaded::Platform.respond_to?(:clipboard_write)
        KantoReloaded::Platform.clipboard_write(text)
      rescue
        false
      end

      def joiplay?
        defined?(KantoReloaded::Platform) &&
          KantoReloaded::Platform.respond_to?(:joiplay?) &&
          KantoReloaded::Platform.joiplay?
      rescue
        false
      end

      def platform_open_url(url)
        return false unless defined?(KantoReloaded::Platform)
        return false unless KantoReloaded::Platform.respond_to?(:open_url)
        KantoReloaded::Platform.open_url(url)
      rescue
        false
      end

      def display_path(path)
        return KantoReloaded::Platform.display_path(path) if defined?(KantoReloaded::Platform)
        File.basename(path.to_s)
      rescue
        "LatestBugReport.txt"
      end

      def sanitized_error(error)
        return _INTL("Unknown error.") unless error
        KantoReloaded::Log.sanitize("#{error.class}: #{error.message}")
      rescue
        _INTL("Unknown error.")
      end

      def progress_ui_available?
        defined?(Graphics) && defined?(Input) && defined?(Viewport) &&
          defined?(Sprite) && defined?(Bitmap) &&
          defined?(KantoReloaded::UI::PopupWindow)
      end

      def log_exception(message, exception)
        return unless defined?(KantoReloaded::Log)
        KantoReloaded::Log.exception(message, exception, channel: :framework)
      rescue
        nil
      end
    end

    class ExportProgressScene
      WIDTH = 320
      HEIGHT = 112

      def initialize(worker, options = {})
        @worker = worker
        @title = options[:title] || _INTL("Exporting Bug Report")
        @cancel_prompt = options[:cancel_prompt] ||
                         _INTL("Cancel the bug report export?")
        @state = {
          :message => options[:initial_message] ||
                      _INTL("Preparing bug report...")
        }
        @cancelled = false
      end

      def main
        setup
        start_worker
        update_loop
      ensure
        stop_worker if @cancelled
        dispose
      end

      private

      def setup
        @viewport = Viewport.new(
          0, 0,
          KantoReloaded::UI::PopupWindow::SCREEN_W,
          KantoReloaded::UI::PopupWindow::SCREEN_H
        )
        @viewport.z = 999_999_990
        @dim_sprite = Sprite.new(@viewport)
        @dim_sprite.bitmap = Bitmap.new(
          KantoReloaded::UI::PopupWindow::SCREEN_W,
          KantoReloaded::UI::PopupWindow::SCREEN_H
        )
        @dim_sprite.bitmap.fill_rect(
          0, 0,
          KantoReloaded::UI::PopupWindow::SCREEN_W,
          KantoReloaded::UI::PopupWindow::SCREEN_H,
          KantoReloaded::UI::PopupWindow::DIM_BG
        )
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(WIDTH, HEIGHT)
        @sprite.x = (KantoReloaded::UI::PopupWindow::SCREEN_W - WIDTH) / 2
        @sprite.y = (KantoReloaded::UI::PopupWindow::SCREEN_H - HEIGHT) / 2
        draw
      end

      def start_worker
        @thread = Thread.new do
          begin
            @state[:outcome] = @worker.call(proc { |message| @state[:message] = message.to_s })
          rescue StandardError => e
            @state[:outcome] = { :success => false, :error => e }
          ensure
            @state[:finished] = true
          end
        end
      end

      def update_loop
        loop do
          Graphics.update
          Input.update
          return @state[:outcome] if @state[:finished]
          if KantoReloaded::UI::InputRouter.input_triggered?(:BACK)
            if KantoReloaded.confirm(
              @cancel_prompt,
              :default => false,
              :z => @viewport.z + 10
            )
              @cancelled = true
              return { :cancelled => true }
            end
          end
          draw if ((Graphics.frame_count rescue 0) % 3).zero?
          sleep(0.01)
        end
      end

      def draw
        bitmap = @sprite.bitmap
        bitmap.clear
        pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
        popup = KantoReloaded::UI::PopupWindow
        draw = KantoReloaded::UI::Draw
        theme = popup::THEMES[:hr]
        draw.rounded_rect(bitmap, 0, 0, WIDTH, HEIGHT,
                          popup::PANEL_RADIUS, theme[:border])
        draw.rounded_rect(bitmap, 1, 1, WIDTH - 2, HEIGHT - 2,
                          popup::PANEL_RADIUS - 1, theme[:background])
        draw.plain_text(
          bitmap, 14, 6, WIDTH - 28, 24,
          @title, theme[:title], 1
        )
        draw.plain_text(
          bitmap, 14, 36, WIDTH - 28, 22,
          @state[:message].to_s, theme[:text], 1, 16
        )
        draw_progress_bar(bitmap)
        if defined?(KantoReloaded::UI::HintText)
          KantoReloaded::UI::HintText.draw(
            bitmap,
            [KantoReloaded::UI::HintText.back("Cancel")],
            14, HEIGHT - 27, WIDTH - 28,
            :size => 13
          )
        end
      end

      def draw_progress_bar(bitmap)
        popup = KantoReloaded::UI::PopupWindow
        draw = KantoReloaded::UI::Draw
        x = 28
        y = 66
        width = WIDTH - 56
        draw.rounded_rect(bitmap, x, y, width, 10, 4,
                          Color.new(18, 25, 45, 230), popup::PANEL_BORDER)
        travel = [width - 58, 1].max
        offset = ((Graphics.frame_count rescue 0) * 3) % (travel * 2)
        offset = travel * 2 - offset if offset > travel
        draw.rounded_rect(bitmap, x + 3 + offset, y + 2, 52, 6, 3,
                          popup::BLUE)
      end

      def stop_worker
        return unless @thread && @thread.alive?
        @thread.kill
        @thread.join rescue nil
      rescue
        nil
      end

      def dispose
        if @dim_sprite
          @dim_sprite.bitmap.dispose if @dim_sprite.bitmap && !@dim_sprite.bitmap.disposed?
          @dim_sprite.dispose unless @dim_sprite.disposed?
        end
        if @sprite
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.dispose unless @sprite.disposed?
        end
        @viewport.dispose if @viewport && !@viewport.disposed?
      rescue
        nil
      end
    end
  end
end

KantoReloaded::BugReport.install

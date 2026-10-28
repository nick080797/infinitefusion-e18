#==============================================================================
# Kanto Reloaded ZIP Asset Packs
#==============================================================================

module KantoReloaded
  module AssetPacks
    ZIP_LOCAL_SIGNATURE = 0x04034B50
    ZIP_CENTRAL_SIGNATURE = 0x02014B50
    MAX_ENTRIES = 10_000
    MAX_PATH_BYTES = 1_024
    FOLLOWER_ROOT = File.expand_path(
      File.join(KantoReloaded::ROOT, "..", "..", "Graphics", "Characters", "Followers")
    ).freeze
    FOLLOWER_PACKS = [
      ["Fusions/Shiny/", "FollowersShiny.pak"],
      ["Fusions/", "Followers.pak"]
    ].freeze

    @indexes = {}
    @warnings = {}

    class << self
      def ensure_follower(relative_path)
        clean = safe_relative_path(relative_path)
        return nil unless clean
        destination = File.join(FOLLOWER_ROOT, *clean.split("/"))
        pack_info = FOLLOWER_PACKS.find { |entry| clean.start_with?(entry[0]) }
        return destination if File.file?(destination) && !pack_info
        return nil unless pack_info
        prefix, filename = pack_info
        member = clean[prefix.length..-1]
        pack_path = follower_pack_path(filename)
        return destination if File.file?(destination) && !File.file?(pack_path)
        return destination if current_entry?(
          pack_path, member, destination, clean
        )
        extract(pack_path, member, destination, clean)
      rescue StandardError => e
        warn_once("follower:#{relative_path}", "Follower ZIP extraction failed", e)
        nil
      end

      def cleanup_legacy_follower_sources
        return false unless FOLLOWER_PACKS.all? do |entry|
          File.file?(follower_pack_path(entry[1]))
        end
        legacy = File.expand_path(
          File.join(KantoReloaded::ROOT, "Graphics", "Characters", "Followers", "Fusions")
        )
        root_prefix = File.expand_path(KantoReloaded::ROOT) + File::SEPARATOR
        return false unless legacy.start_with?(root_prefix)
        return false unless File.directory?(legacy)
        removed = 0
        Dir[File.join(legacy, "*.png")].each do |path|
          File.delete(path)
          removed += 1
        end
        shiny = File.join(legacy, "Shiny")
        if File.directory?(shiny)
          removed += Dir[File.join(shiny, "**", "*")].count do |path|
            File.file?(path)
          end
          remove_tree(shiny)
        end
        return false if removed == 0
        KantoReloaded::Log.info(
          "Removed #{removed} legacy loose Wild Link follower assets",
          :assets
        ) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        warn_once("legacy_cleanup", "Could not remove legacy follower assets", e)
        false
      end

      private

      def extract(pack_path, member, destination, manifest_relative)
        entry = index_for(pack_path)[member]
        return nil unless entry
        packed = File.open(pack_path, "rb") do |file|
          file.seek(entry[:offset])
          file.read(entry[:compressed_length])
        end
        raise "Incomplete ZIP entry: #{member}" unless packed &&
                                                       packed.bytesize == entry[:compressed_length]
        data = inflate_entry(packed, entry[:method])
        unless data.bytesize == entry[:length] && Zlib.crc32(data) == entry[:crc]
          raise "ZIP entry failed verification: #{member}"
        end
        ensure_directory(File.dirname(destination))
        temporary = destination + ".krpack.tmp"
        File.open(temporary, "wb") { |file| file.write(data) }
        File.delete(destination) if File.file?(destination)
        File.rename(temporary, destination)
        register_installed_asset(
          "Graphics/Characters/Followers/#{manifest_relative}"
        )
        destination
      ensure
        File.delete(temporary) if temporary && File.file?(temporary)
      end

      def inflate_entry(data, method)
        return data if method == 0
        raise "Unsupported ZIP compression method #{method}" unless method == 8
        inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        result = inflater.inflate(data)
        result << inflater.finish
        result
      ensure
        inflater.close if inflater
      end

      def current_entry?(pack_path, member, destination, manifest_relative)
        return false unless File.file?(destination)
        entry = index_for(pack_path)[member]
        return false unless entry
        return false unless File.size(destination) == entry[:length]
        current = File.binread(destination)
        if Zlib.crc32(current) == entry[:crc]
          register_installed_asset(
            "Graphics/Characters/Followers/#{manifest_relative}"
          )
          true
        else
          false
        end
      rescue StandardError
        false
      end

      def index_for(pack_path)
        raise "Missing follower ZIP pack: #{pack_path}" unless File.file?(pack_path)
        signature = [File.size(pack_path), File.mtime(pack_path).to_i]
        cached = @indexes[pack_path]
        return cached[:entries] if cached && cached[:signature] == signature
        entries = read_index(pack_path)
        @indexes[pack_path] = { :signature => signature, :entries => entries }
        entries
      end

      def read_index(pack_path)
        entries = {}
        File.open(pack_path, "rb") do |file|
          loop do
            signature_data = file.read(4)
            break if !signature_data || signature_data.empty?
            raise "Truncated ZIP signature" unless signature_data.bytesize == 4
            signature = signature_data.unpack("V")[0]
            break if signature == ZIP_CENTRAL_SIGNATURE
            raise "Invalid ZIP local header" unless signature == ZIP_LOCAL_SIGNATURE
            fields = read_exact(file, 26).unpack("vvvvvVVVvv")
            _version, flags, method, _time, _date, crc,
              compressed_length, length, name_length, extra_length = fields
            raise "Encrypted ZIP entries are unsupported" unless (flags & 0x0001) == 0
            raise "ZIP data descriptors are unsupported" unless (flags & 0x0008) == 0
            raise "Unsupported ZIP compression method #{method}" unless [0, 8].include?(method)
            if name_length < 1 || name_length > MAX_PATH_BYTES
              raise "Invalid ZIP path length #{name_length}"
            end
            name = safe_relative_path(read_exact(file, name_length))
            raise "Unsafe ZIP path" unless name
            file.seek(extra_length, IO::SEEK_CUR)
            data_offset = file.pos
            unless name.end_with?("/")
              raise "Duplicate ZIP path: #{name}" if entries.key?(name)
              entries[name] = {
                :offset => data_offset,
                :compressed_length => compressed_length,
                :length => length,
                :crc => crc,
                :method => method
              }
              raise "Too many ZIP entries" if entries.length > MAX_ENTRIES
            end
            file.seek(compressed_length, IO::SEEK_CUR)
          end
        end
        raise "Follower ZIP pack contains no files" if entries.empty?
        entries
      end

      def follower_pack_path(filename)
        File.join(
          KantoReloaded::ROOT, "Graphics", "Characters", "Followers",
          "Fusions", filename
        )
      end

      def read_exact(file, length)
        value = file.read(length)
        raise "Unexpected end of ZIP pack" unless value && value.bytesize == length
        value
      end

      def safe_relative_path(path)
        value = path.to_s.tr("\\", "/")
        parts = value.split("/")
        return nil if parts.empty?
        return nil if parts.any? { |part| part.empty? || part == "." || part == ".." }
        parts.join("/")
      end

      def ensure_directory(path)
        missing = []
        current = path
        until File.directory?(current)
          parent = File.dirname(current)
          raise "Could not resolve asset directory #{path}" if parent == current
          missing.unshift(current)
          current = parent
        end
        missing.each { |directory| Dir.mkdir(directory) }
      end

      def remove_tree(path)
        Dir[File.join(path, "**", "*")].sort.reverse_each do |entry|
          File.directory?(entry) ? Dir.rmdir(entry) : File.delete(entry)
        end
        Dir.rmdir(path)
      end

      def register_installed_asset(relative_path)
        clean = safe_relative_path(relative_path)
        return unless clean
        manifest = File.join(KantoReloaded::ROOT, ".installed_assets")
        entries = File.file?(manifest) ? File.readlines(manifest).map { |line| line.strip } : []
        return if entries.include?(clean)
        needs_separator = File.file?(manifest) && File.size(manifest) > 0 &&
                          File.open(manifest, "rb") do |file|
                            file.seek(-1, IO::SEEK_END)
                            file.read(1) != "\n"
                          end
        File.open(manifest, "a") do |file|
          file.write("\n") if needs_separator
          file.write(clean)
          file.write("\n")
        end
      rescue StandardError => e
        warn_once("asset_manifest", "Could not register extracted follower asset", e)
      end

      def warn_once(key, message, error)
        return if @warnings[key]
        @warnings[key] = true
        detail = error ? ": #{error.class}: #{error.message}" : ""
        if defined?(KantoReloaded::Log)
          KantoReloaded::Log.warning("#{message}#{detail}", :assets)
        else
          echoln("[KantoReloaded] #{message}#{detail}") rescue nil
        end
      end
    end
  end
end

KantoReloaded::AssetPacks.cleanup_legacy_follower_sources

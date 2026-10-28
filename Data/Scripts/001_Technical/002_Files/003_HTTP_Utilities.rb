#############################
#
# HTTP utility functions
#
#############################

# mkxp-z's HTTPLite methods run the native HTTP request off the main Ruby
# thread with the GVL released, then build the returned Hash/String
# (rb_hash_new/rb_str_new/etc.) BEFORE re-acquiring the GVL. That's a real
# engine bug: allocating Ruby objects without the GVL held races against
# whatever the main thread (incl. the GC) is doing at that instant, and
# has produced reproducible native segfaults here (rb_ary_entry deref of
# a corrupted/nil VALUE). We can't patch the compiled engine from a
# script, but disabling GC for the brief window of the call removes
# GC-driven object movement/collection as one concurrent actor, narrowing
# the race. Not a complete fix, but zero risk and doesn't touch download
# functionality at all. Wrap every HTTPLite.* call site with this.
$http_calls_in_flight = 0
$http_gc_was_enabled_before_guard = true
$http_last_call_finished_at = Time.now - 999

def http_call_gc_guard
  # Reference-counted: if call B starts while call A is still in flight (A's
  # Ruby-visible return can lag behind its native thread actually finishing),
  # only the call that brings the counter back to 0 may re-enable GC. The
  # original version called GC.enable unconditionally on ITS OWN way out,
  # which could re-enable GC while a sibling call's background thread was
  # still active - reopening the exact race this guard exists to close.
  if $http_calls_in_flight == 0
    $http_gc_was_enabled_before_guard = !GC.disable
  end
  $http_calls_in_flight += 1
  begin
    yield
  ensure
    $http_calls_in_flight -= 1
    if $http_calls_in_flight <= 0
      $http_calls_in_flight = 0
      # Grace period before re-enabling GC: the native HTTPLite thread that
      # built this call's return value may still be tearing itself down for
      # a moment after Ruby already has the result in hand, so give it a
      # head start before GC (or anything else) can move/collect concurrently.
      # (Bumped from 50ms - Options was still crashing with 50ms, so that
      # wasn't enough headroom for the native thread to fully unwind.)
      sleep(0.3)
      GC.enable if $http_gc_was_enabled_before_guard
    end
    $http_last_call_finished_at = Time.now
  end
end

# Best-effort mitigation for menus that do heavy redraw/GC work right as
# they open (Options, Mod Manager) - opening one of those exactly while an
# HTTPLite call's background thread is still active is when the native
# rb_ary_entry segfault (see comment above) is most likely to land. This
# can't guarantee the race is gone (the bug is inside the compiled engine),
# but waiting for a quiet gap after the last call meaningfully narrows it.
# Bounded so a stuck/slow request can never hang the menu indefinitely.
def wait_for_http_quiet(max_wait = 3.0, quiet_gap = 0.4)
  deadline = Time.now + max_wait
  loop do
    quiet = $http_calls_in_flight <= 0 && (Time.now - $http_last_call_finished_at) >= quiet_gap
    return true if quiet
    return false if Time.now >= deadline
    sleep(0.02)
  end
end

def pbPostData(url, postdata, filename=nil, depth=0)
  return "" unless url =~ /^https?:\/\/([^\/]+)(.*)$/
  host = $1
  path = $2
  path = "/" if path.empty?

  userAgent = "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.14) Gecko/2009082707 Firefox/3.0.14"

  # Serialize as JSON
  body = serialize_json(postdata)

  ret = http_call_gc_guard {
    HTTPLite.post_body(
      url,
      body,
      "application/json",
      {
        "Host" => host,
        "Proxy-Connection" => "Close",
        "Content-Length" => body.bytesize.to_s,
        "Pragma" => "no-cache",
        "User-Agent" => userAgent
      }
    )
  } rescue ""

  return "" if !ret.is_a?(Hash)
  return "" if ret[:status] != 200
  if filename
    File.open(filename, "wb") { |f| f.write(ret[:body]) }
    return ""
  end
  ret[:body]
end



def pbDownloadData(url, filename = nil, authorization = nil, depth = 0, &block)
  return nil if !downloadAllowed?()
  echoln "downloading data from #{url}"
  headers = {
    "Proxy-Connection" => "Close",
    "Pragma" => "no-cache",
    "User-Agent" => "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.14) Gecko/2009082707 Firefox/3.0.14"
  }
  headers["authorization"] = authorization if authorization
  ret = http_call_gc_guard { HTTPLite.get(url, headers) } rescue ""
  return ret if !ret.is_a?(Hash)
  return "" if ret[:status] != 200
  return ret[:body] if !filename
  File.open(filename, "wb") { |f| f.write(ret[:body]) }
  return ""
end

def pbDownloadToString(url)
  begin
    data = pbDownloadData(url)
    return data if data
    return ""
  rescue
    return ""
  end
end

def pbDownloadToFile(url, file)
  begin
    pbDownloadData(url,file)
  rescue
  end
end

def pbPostToString(url, postdata, timeout = 30)
  safe_postdata = postdata.transform_values(&:to_s)
  begin
    data = pbPostData(url, safe_postdata)
    return data || ""
  rescue MKXPError => e
    echoln("[Remote AI] Exception: #{e.message}")
    return ""
  end
end





def pbPostToFile(url, postdata, file)
  begin
    pbPostData(url, postdata,file)
  rescue
  end
end

def serialize_value_legacy(value)
  if value.is_a?(Hash)
    serialize_json(value)
  elsif value.is_a?(String)
    escaped_value = value.gsub(/\\/, '\\\\\\').gsub(/"/, '\\"').gsub(/\n/, '\\n').gsub(/\r/, '\\r')
    "\"#{escaped_value}\""
  else
    value.to_s
  end
end


def serialize_json(data)
  if data.is_a?(Hash)
    parts = ["{"]
    data.each_with_index do |(key, value), index|
      parts << "\"#{key}\":#{serialize_value(value)}"
      parts << "," unless index == data.size - 1
    end
    parts << "}"
    return parts.join
  else
    return serialize_value(data)
  end
end

def serialize_value(value)
  case value
  when String
    "\"#{escape_json_string(value)}\""
  when Numeric
    value.to_s
  when TrueClass, FalseClass
    value.to_s
  when NilClass
    "null"
  when Array
    "[" + value.map { |v| serialize_value(v) }.join(",") + "]"
  when Hash
    serialize_json(value)
  else
    raise "Unsupported type: #{value.class}"
  end
end

def escape_json_string(str)
  # Minimal escape handling
  str.gsub(/["\\]/) { |m| "\\#{m}" }
    .gsub("\n", "\\n")
    .gsub("\t", "\\t")
    .gsub("\r", "\\r")
end



def downloadAllowed?()
  # Sprite downloading forced ON at the user's request, regardless of the
  # $PokemonSystem.download_sprites toggle/Options UI checkbox.
  return true
end

def clean_json_string(str)
  #echoln str
  #return str if $PokemonSystem.on_mobile
  # Remove non-UTF-8 characters and unexpected control characters
  #cleaned_str = str.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
  cleaned_str = str
  # Remove literal \n, \r, \t, etc.
  cleaned_str = cleaned_str.gsub(/\\n|\\r|\\t/, '')

  # Remove actual newlines and carriage returns
  cleaned_str = cleaned_str.gsub(/[\n\r]/, '')

  # Remove leading and trailing quotes
  cleaned_str = cleaned_str.gsub(/\A"|"\Z/, '')

  # Replace Unicode escape sequences with corresponding characters
  cleaned_str = cleaned_str.gsub(/\\u([\da-fA-F]{4})/) { |match|
    [$1.to_i(16)].pack("U")
  }
  return cleaned_str
end


# json.rb - lightweight JSON parser for MKXP/RGSS XP

# Lightweight JSON for MKXP/RGSS XP
module JSON
  module_function

  # Convert Ruby object (hash/array/etc) into JSON string
  def generate(obj)
    case obj
    when Hash
      "{" + obj.map { |k, v| "\"#{k}\":#{generate(v)}" }.join(",") + "}"
    when Array
      "[" + obj.map { |v| generate(v) }.join(",") + "]"
    when String, Symbol
      "\"#{obj.to_s}\""
    when TrueClass, FalseClass
      obj.to_s
    when NilClass
      "null"
    when Numeric
      obj.to_s
    else
      raise "Unsupported type #{obj.class}"
    end
  end

  # Simple parser (not full JSON) — optional
  def parse(str)
    return nil if str.nil? || str.strip.empty?
    eval(str)
  end
end












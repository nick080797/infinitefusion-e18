#!/usr/bin/env ruby

require "fileutils"
require "zlib"

module KantoReloadedFollowerPacks
  LOCAL_SIGNATURE = 0x04034B50
  CENTRAL_SIGNATURE = 0x02014B50
  END_SIGNATURE = 0x06054B50
  VERSION = 20
  DOS_TIME = 0
  DOS_DATE = 33
  ROOT = File.expand_path("..", __dir__)
  PACKS = {
    "Followers.pak" => [
      File.join(ROOT, "Graphics", "Characters", "Followers", "Fusions"),
      File.join(ROOT, "Graphics", "Characters", "Followers", "Fusions", "Followers.pak")
    ],
    "FollowersShiny.pak" => [
      File.join(ROOT, "Graphics", "Characters", "Followers", "Fusions", "Shiny"),
      File.join(ROOT, "Graphics", "Characters", "Followers", "Fusions", "FollowersShiny.pak")
    ]
  }.freeze

  module_function

  def pack_all
    PACKS.each_value do |source, destination|
      files = Dir.glob(File.join(source, "*.png")).sort
      raise "No PNG files found in #{source}" if files.empty?
      records = files.map do |path|
        data = File.binread(path)
        name = File.basename(path).encode(Encoding::UTF_8).b
        [name, data, Zlib.crc32(data)]
      end
      FileUtils.mkdir_p(File.dirname(destination))
      temporary = destination + ".tmp"
      write_zip(temporary, records)
      verify_pack(temporary)
      FileUtils.mv(temporary, destination, :force => true)
      puts "Packed #{records.length} files into #{destination}"
    ensure
      FileUtils.rm_f(temporary) if temporary
    end
  end

  def write_zip(path, records)
    central = []
    File.open(path, "wb") do |file|
      records.each do |name, data, crc|
        local_offset = file.pos
        file.write([
          LOCAL_SIGNATURE, VERSION, 0, 0, DOS_TIME, DOS_DATE,
          crc, data.bytesize, data.bytesize, name.bytesize, 0
        ].pack("VvvvvvVVVvv"))
        file.write(name)
        file.write(data)
        central << [name, data.bytesize, crc, local_offset]
      end
      central_offset = file.pos
      central.each do |name, length, crc, local_offset|
        file.write([
          CENTRAL_SIGNATURE, VERSION, VERSION, 0, 0, DOS_TIME, DOS_DATE,
          crc, length, length, name.bytesize, 0, 0, 0, 0, 0, local_offset
        ].pack("VvvvvvvVVVvvvvvVV"))
        file.write(name)
      end
      central_size = file.pos - central_offset
      file.write([
        END_SIGNATURE, 0, 0, central.length, central.length,
        central_size, central_offset, 0
      ].pack("VvvvvVVv"))
    end
  end

  def unpack_all
    PACKS.each_value do |destination, pack_path|
      FileUtils.mkdir_p(destination)
      each_entry(pack_path) do |name, data, _crc|
        File.binwrite(File.join(destination, name), data)
      end
      puts "Unpacked #{pack_path} into #{destination}"
    end
  end

  def verify_all
    PACKS.each_value do |source, path|
      count = 0
      minimum_width = nil
      minimum_height = nil
      each_entry(path) do |name, data, _crc|
        width, height = png_dimensions(data, name)
        minimum_width = width if !minimum_width || width < minimum_width
        minimum_height = height if !minimum_height || height < minimum_height
        if width < 64 || height < 64
          raise "Follower graphic is too small for Wild Link: #{name} (#{width}x#{height})"
        end
        original = File.join(source, name)
        if File.file?(original) && File.binread(original) != data
          raise "Packed data differs from source: #{original}"
        end
        count += 1
      end
      puts "Verified ZIP #{path}: #{count} PNG files, minimum #{minimum_width}x#{minimum_height}"
    end
  end

  def verify_pack(path)
    count = 0
    each_entry(path) { |_name, _data, _crc| count += 1 }
    count
  end

  def each_entry(path)
    File.open(path, "rb") do |file|
      loop do
        signature_data = file.read(4)
        break if !signature_data || signature_data.empty?
        signature = exact_data(signature_data, 4).unpack1("V")
        break if signature == CENTRAL_SIGNATURE
        raise "Invalid ZIP local header" unless signature == LOCAL_SIGNATURE
        fields = exact(file, 26).unpack("vvvvvVVVvv")
        _version, flags, method, _time, _date, crc,
          packed_length, length, name_length, extra_length = fields
        raise "Unsupported ZIP flags" unless (flags & 0x0009) == 0
        raise "Unsupported ZIP compression method #{method}" unless method == 0
        name = exact(file, name_length).force_encoding(Encoding::UTF_8)
        file.seek(extra_length, IO::SEEK_CUR)
        data = exact(file, packed_length)
        raise "ZIP length mismatch for #{name}" unless data.bytesize == length
        raise "ZIP CRC mismatch for #{name}" unless Zlib.crc32(data) == crc
        yield(name, data, crc)
      end
    end
  end

  def exact(file, length)
    exact_data(file.read(length), length)
  end

  def exact_data(data, length)
    raise "Unexpected end of ZIP file" unless data && data.bytesize == length
    data
  end

  def png_dimensions(data, name)
    signature = "\x89PNG\r\n\x1A\n".b
    raise "Invalid PNG signature: #{name}" unless data.start_with?(signature)
    raise "Missing PNG IHDR: #{name}" unless data.bytesize >= 24 && data[12, 4] == "IHDR"
    width, height = data[16, 8].unpack("NN")
    raise "Invalid PNG dimensions: #{name}" if width < 1 || height < 1
    [width, height]
  end
end

command = (ARGV.shift || "verify").downcase
case command
when "pack"
  KantoReloadedFollowerPacks.pack_all
when "unpack"
  KantoReloadedFollowerPacks.unpack_all
when "verify"
  KantoReloadedFollowerPacks.verify_all
else
  warn "Usage: ruby Tools/FollowerPacks.rb [pack|unpack|verify]"
  exit 1
end

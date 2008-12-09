require 'digest/sha1'
require 'fileutils'
class Message
  attr_accessor :body
  attr_reader :mail

  class << self
    attr_reader   :queue_path
    attr_accessor :recipient_header_order
  end

  def self.queue_path=(path)
    FileUtils.mkdir_p path
    @queue_path = File.expand_path(path)
  end

  self.recipient_header_order = %w(original_to delivered_to to)
  self.queue_path = File.join(File.dirname(__FILE__), '..', '..', 'queue')

  def self.queue(raw)
    filename = nil
    digest   = Digest::SHA1.hexdigest(raw)
    while filename.nil? || File.exist?(filename)
      filename = File.join(queue_path, Digest::SHA1.hexdigest(digest + rand.to_s))
    end
    File.open filename, 'wb' do |f|
      f.write raw
    end
    filename
  end

  def self.receive(raw)
    message = parse(raw)
    Mapping.process(message)
  end

  def self.parse(raw)
    new TMail::Mail.parse(raw)
  end

  def initialize(mail)
    @mail    = mail
    @mapping = nil
  end

  def recipient(order = nil)
    order = self.class.recipient_header_order if order.blank?
    order.each do |key|
      value = send("recipient_from_#{key}")
      return value unless value.blank?
    end
  end

  def recipient_from_to
    @recipient_from_to ||= @mail['to'].to_s
  end

  def recipient_from_delivered_to
    @recipient_from_delivered_to ||= @mail['Delivered-To'].to_s
  end

  def recipient_from_original_to
    @recipient_from_original_to ||= @mail['X-Original-To'].to_s
  end

  def sender
    @sender ||= @mail['from'].to_s
  end

  def subject
    @mail.subject
  end

  def body
    @body ||= begin
      if @mail.multipart?
        scan_parts(@mail)
        @body ||= ""
      else
        @mail.body
      end
    end
  end

  def raw
    @mail.port.to_s
  end

protected
  def scan_parts(message)
    message.parts.each do |part|
      if part.multipart?
        scan_parts(part)
      else
        if part.content_type == "text/plain"
          @body = part.body
        end
      end
    end
  end
end
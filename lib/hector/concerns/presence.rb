module Hector
  module Concerns
    module Presence
      def self.included(klass)
        klass.class_eval do
          attr_reader :created_at, :updated_at
        end
      end

      def channels
        Channel.find_all_for_session(self)
      end

      def initialize_presence
        @created_at = Time.now
        @updated_at = Time.now
        deliver_welcome_message
      end

      def destroy_presence
        deliver_quit_message
        leave_all_channels
      end

      def seconds_idle
        Time.now - updated_at
      end

      def peer_sessions
        [self, *channels.map { |channel| channel.sessions }.flatten].uniq
      end

      def touch_presence
        @updated_at = Time.now
      end

      protected
        def deliver_welcome_message
          respond_with("001", nickname, :text => "Welcome to #{Hector.server_name}")
          welcome_message_path = Hector.root.join("config/motd.txt")
          if File.exist?(welcome_message_path)
            respond_with("375", :text => "#{Hector.server_name} IRC Message Of The Day")
            File.foreach(welcome_message_path) { |line|
              respond_with("372", :text => line)
            }
            respond_with("376", :text => "End of MOTD")
          else
            respond_with("422", :text => "MOTD File missing")
          end
        end

        def deliver_quit_message
          broadcast(:quit, :source => source, :text => quit_message, :except => self)
          respond_with(:error, :text => "Closing Link: #{nickname}[hector] (#{quit_message})")
        end

        def leave_all_channels
          channels.each do |channel|
            channel.part(self)
          end
        end

        def quit_message
          @quit_message || "Connection closed"
        end
    end
  end
end

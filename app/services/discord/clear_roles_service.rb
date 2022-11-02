module Discord
  class ClearRolesService
    def initialize(discord_user_id, configuration)
      @discord_user_id = discord_user_id
      @configuration = configuration
    end

    def execute
      return if @configuration.blank?

      begin
        Discordrb::API::Server.update_member(
          "Bot #{@configuration['bot_token']}",
          @configuration['server_id'],
          @discord_user_id,
          roles: []
        )
      rescue Discordrb::Errors::NoPermission
        Rails.logger.error "No permission to update member #{@discord_user_id}"
      rescue RestClient::BadRequest
        Rails
          .logger.error "Bad request with discord_user_id: #{@discord_user_id}"
      end
    end
  end
end

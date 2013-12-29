class FacebookAccount < ActiveRecord::Base
 
  # Stubbed out! Does no (good) error checking!  

 
  def authorize_url(callback_url = '')
    if self.oauth_authorize_url.blank?
      self.oauth_authorize_url = "https://graph.facebook.com/oauth/authorize?client_id=#{FACEBOOK_CLIENT_ID}&redirect_uri=#{callback_url}&scope=offline_access,publish_stream,read_stream"
      self.save!
    end
    self.oauth_authorize_url
  end
  
  def validate_oauth_token(oauth_verifier, callback_url = '')
    response = RestClient.get "https://graph.facebook.com/oauth/access_token?client_id=#{FACEBOOK_CLIENT_ID}&redirect_uri=#{callback_url.html_safe}&client_secret=#{FACEBOOK_CLIENT_SECRET}&code=#{oauth_verifier.html_safe}"
    pair = response.body.split("&")[0].split("=")
    if (pair[0] == "access_token")
      self.access_token = pair[1]
      response = RestClient.get 'https://graph.facebook.com/me', :params => { :access_token => self.access_token }
      self.stream_url = JSON.parse(response.body)["link"]
      self.active = true
    else 
      self.errors.add(:oauth_verifier, "Invalid token, unable to connect to facebook: #{pair[1]}")
      self.active = false
    end
    self.save!
  end
  
  def post(message)
    RestClient.post 'https://graph.facebook.com/me/feed', { :access_token => self.access_token, :message => message }
  end

  def get_feed
    response = RestClient.get "https://graph.facebook.com/me/feed", :params => { :access_token => self.access_token, :limit => 110 }
    ActiveSupport::JSON.decode( response.body )
  end

  def post_comment( post_id, message )
    RestClient.post "https://graph.facebook.com/#{post_id}/comments", { :access_token => self.access_token, :message => message }
  end

  def like_post( post_id )
    RestClient.post "https://graph.facebook.com/#{post_id}/likes", { :access_token => self.access_token }
  end

  def add_comment_and_like_on_post( post_id, message )
    post_comment( post_id, message )
    like_post( post_id )
  end

  # words = ["hbd", "happy", "birthday", "bday", "b'day", "bdy", "happie", "hpy", "returns"]
  # pass the words array to match in the posts
  # a random message from message_array will be taken and added to the comment
  # messages = ["Thank you so much", "Thank you", "Thanks for the wishes", "Thank you for the wishes", "Thanks a lot", "Many Thanks"]
  def like_and_post_on_matching_feed( words_to_match, messages_array )
    regex = /#{words_to_match.map{|w|Regexp.escape(w)}.join('|')}/i
    
    messages = []
    
    posts = get_feed.each do |post|
      name = post["message"]
      if regex === name
        message = "#{messages_array.sample} #{post['from']['name']}"
        messages << message
        add_comment_and_like_on_post( post["id"], message )
      end
    end
  end


 
end
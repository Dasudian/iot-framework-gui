class StreamsController < ApplicationController

  before_action :set_stream, only: [:show, :edit, :update, :destroy]
	before_action :signed_in_user, only: [:index, :edit, :update, :destroy]
	before_action :correct_user,   only: [:edit, :update, :destroy]

  def index
    # @streams = Stream.search(params[:search])
    response = Faraday.get "http://srv1.csproj13.student.it.uu.se:8000/users/#{current_user.id}/streams"
		@streams = JSON.parse(response.body)['streams']
		logger.debug "TESSSSSTTTT: #{@streams}"
  end

  def show
		@user = current_user
  end

  def new
    @stream = Stream.new
    # attributes = ["name", "description", "type", "private",
    #               "tags", "accuracy", "unit", "min_val", "max_val", "latitude", "longitude",
    #               "polling", "uri", "polling_freq",
    #               "user_id"]
    # attributes.each do |attr|
    #   @stream.send("#{attr}=", "")
    # end
  end

  def new_from_resource
  end

  def make_suggestion_by model
    res = Faraday.get "#{CONF['API_URL']}/suggest/#{model}?size=10"
    logger.debug JSON.parse(res.body)
    if res.status == 404
      data = {}
    else
      data = JSON.parse(res.body)['suggestions']
    end

    data
  end

  def suggest
    sug = make_suggestion_by params[:model]
    status = if sug then 200 else 404 end
    render :json => sug, :status => status
  end

  def fetchResource
    res = Faraday.get "#{CONF['API_URL']}/resources/#{params[:id]}"
    # render :json => res.body, :status => res.status
    # json = JSON.parse(res.body)
    # @streams = []
    # json['streams_suggest'].each do |jstream|
    #   stream = Stream.new

    #   jstream.each do |k, v|
    #     stream.send("#{k}=", v)
    #     stream.send("private=", "")
    #     stream.send("longitude=", "")
    #     stream.send("latitude=", "")
    #     stream.send("uri=", "")
    #   end
    #   logger.debug stream.attributes
    #   @streams.push stream
    # end

    # render :layout => false
    render :json => res.body, :status => res.status
  end

  def smartnew
    logger.debug "CREATE: #{params}"
    # @multistream = Multistream.new(multistream_params)
    # @multistream = Multistream.new
    @user = current_user
    params[:multistream].each do |k, v|
      # st = Stream.new v
      # logger.debug "Stream created: #{st.attributes}"
      @user.streams.build v
    end

    respond_to do |format|
      # format.html { redirect_to smartnew_stream_path }
      format.html { render action: 'new' }
      format.json { render action: 'new' }
    end
  end

  def edit
    logger.debug "#{@stream.attributes}"

    if @stream.accuracy      == nil then @stream.accuracy     = "" end
    if @stream.min_val       == nil then @stream.min_val      = "" end
    if @stream.max_val       == nil then @stream.max_val      = "" end
    if @stream.polling_freq  == nil then @stream.polling_freq = "" end
    if @stream.location      == nil then @stream.location     = "," end

    logger.debug "#{@stream.attributes}"

    location = @stream.location.split(",", 2)

    @stream.send("latitude=", location[0])
    @stream.send("longitude=", location[1])
  end

  def correctBooleanFields
    @stream.location = "#{@stream.latitude},#{@stream.longitude}"
    @stream.attributes.delete 'longitude'
    @stream.attributes.delete 'latitude'

    # Remove attributes when editing a stream
    @stream.attributes.delete 'active'
    @stream.attributes.delete 'user_ranking'
    @stream.attributes.delete 'last_updated'
    @stream.attributes.delete 'history_size'
    @stream.attributes.delete 'creation_date'
    @stream.attributes.delete 'quality'
    @stream.attributes.delete 'subscribers'

    @stream.polling = if @stream.polling == "0" then "false" else "true" end
    @stream.private = if @stream.private == "0" then "false" else "true" end

    if @stream.accuracy     == ""  then @stream.accuracy     = nil end
    if @stream.min_val      == ""  then @stream.min_val      = nil end
    if @stream.max_val      == ""  then @stream.max_val      = nil end
    if @stream.polling_freq == ""  then @stream.polling_freq = nil end
    if @stream.location     == "," then @stream.location     = nil end
  end

  def create
    @stream = Stream.new(stream_params)
    correctBooleanFields

    logger.debug "attributes"
    logger.debug @stream.attributes

    respond_to do |format|
    	res = post
        logger.debug "BODY: #{res.body}"
      	if res.status == 200

          @stream.id = JSON.parse(res.body)['_id']
  				# TODO
          # The API is currently sending back the response before the database has
  				# been updated. The line below will be removed once this bug is fixed.
        	sleep(1.0)

  				format.html { redirect_to stream_path(@stream.id) }
        	format.json { render action: 'show', status: :created, location: @stream }
      	else
        	format.html { render action: 'new' }
        	format.json { render json: @stream.errors, status: :unprocessable_entity }
      	end
    end
  end

  def update
    @stream.assign_attributes(stream_params)
    correctBooleanFields

    respond_to do |format|
    	res = put
      logger.debug "attributes: #{@stream.attributes}"
    	res.on_complete do
      	if res.status == 200
          # TODO
          # The API is currently sending back the response before the database has
          # been updated. The line below will be removed once this bug is fixed.
					sleep(1.0)

        	format.html { redirect_to stream_path(@stream.id) }
        	format.json { head :no_content }
      	else
        	format.html { render action: 'edit' }
        	format.json { render json: @stream.errors, status: :unprocessable_entity }
      	end
    	end
    end
  end

  def destroy
    @stream.destroy

    # TODO
    # The API is currently sending back the response before the database has
    # been updated. The line below will be removed once this bug is fixed.
		sleep(1.0)

    respond_to do |format|
      format.html { redirect_to streams_path }
      format.json { head :no_content }
    end
  end

  def destroyAll
    deleteAll
    # TODO
    # The API is currently sending back the response before the database has
    # been updated. The line below will be removed once this bug is fixed.
    sleep(1.0)

    respond_to do |format|
      format.html { redirect_to streams_path }
      format.json { head :no_content }
    end
  end

  def fetch_datapoints
    res = Faraday.get "#{CONF['API_URL']}/streams/" + params[:id] + "/data/_search"
    respond_to do |format|
      format.json { render json: res.body, status: res.status }
    end
  end

  def fetch_prediction
    res = Faraday.get "#{CONF['API_URL']}/streams/" + params[:id] + "/_analyse"
    logger.debug "RES: #{res.body}"
    respond_to do |format|
      format.json { render json: res.body, status: res.status }
    end
  end

  def deleteAll
    cid = current_user.id
    url = "#{CONF['API_URL']}/users/#{cid}/streams/"
    send_data(:delete, url)
  end

  def post
    cid = current_user.id
    url = "#{CONF['API_URL']}/users/#{cid}/streams/"
    send_data(:post, url)
  end

  def put
    cid = current_user.id
    url = "#{CONF['API_URL']}/users/#{cid}/streams/#{@stream.id}"
    @stream.attributes.delete 'id'
    send_data(:put, url)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_stream
      #@stream = Stream.find(params[:id], _user_id: current_user.id)
      @stream = Stream.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def stream_params
      params.require(:stream).permit(:name, :description, :type, :private, :tags, :accuracy, :unit, :min_val, :max_val, :longitude, :latitude, :polling, :uri, :polling_freq)
    end

    # def load_parent
    #   @user = User.find(current_user.id)
    # end

    def send_data(method, url)
      new_connection unless @conn
      @conn.send(method) do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.body = @stream.attributes.to_json if @stream
      end
    end

    def new_connection
      cid = current_user.id
      @conn = Faraday.new(:url => "#{CONF['API_URL']}/users/#{cid}/") do |faraday|
        faraday.request  :url_encoded               # form-encode POST params
        faraday.response :logger                    # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter    # make requests with Net::HTTP
      end
		end

		# Before filters
		def signed_in_user
			unless signed_in?
				store_location
				flash[:warning] = "Please sign in"
				redirect_to signin_url
			end
		end

		def correct_user
			@user = User.find(Stream.find(params[:id]).user_id)
			redirect_to(root_url) unless current_user?(@user)
		end
end

require 'sinatra/base'
require 'SecureRandom'
require 'HTTParty'
require 'slim'
if settings.development?
  require 'sinatra/reloader'
  require 'pry'
end

temp = HTTParty.get('http://ws.audioscrobbler.com/2.0/user/darthophage/toptracks.xml')
@@lastfm = temp["toptracks"]["track"]

class Time
  def humanize
    self.strftime("%A, %B #{self.day.ordinalize}, %Y")
  end
end

module Apphelpers
  def trim(data=nil)
    proc = Proc.new {|k, v| v.delete_if(&proc) if v.kind_of?(Hash); v.empty? }
    data.delete_if(&proc)
  end
  def tagarray(t); t.strip.gsub(/(\^\s\*|\d)/, "").gsub(/\s+/, " ").split(", "); end
  def search(pattern="")
    stringarray = pattern.strip.gsub(/(\^\s\*|\d)/, "").downcase.gsub(/\s+/, " ").split(", ")
    stringarray.collect!{|s| Regexp.new(s, true)}
    Folio.or({:tag.in => stringarray}, {:title.in => stringarray}, {:paragraphy.in => stringarray}).desc(:created)
  end
  def check(url=nil)
    (url =~ /http\:\/\//) == 0
  end
end

class Website < Sinatra::Base
  helpers Apphelpers
  enable :inline_templates
  enable :sessions
  set :app_file, __FILE__
  set :root, File.dirname(__FILE__)
  set :views, 'views'
  set :public_folder, 'static'
  Mongoid.load! "config/mongoid.yml"
  # register Sinatra::Partial
  # Slim::Engine.set_default_options :pretty => true
  # set :slim, :layout_engine => :slim
  # set :partial_template_engine, :slim

  configure :development do
    register Sinatra::Reloader
    Bundler.require(:development)
    get "/binding" do
      binding.pry
    end
  end

  configure :production do
    Bundler.require(:production)
  end

  before do
    session[:quotes] = Quote.all.entries.collect(&:id).shuffle if session[:quotes].nil?
  end

  get "/?" do
    @github = github
    @folio = Folio.desc(:created).limit(3).entries
    @quote = Quote.find(session[:quotes][0])
    status 200
    slim :index
  end
  get '/folio' do
    @github = github
    @folio = Folio.desc(:created).limit(3).skip(params["skip"]||0)
    @quote = Quote.find(session[:quotes][params["skip"].to_i/3])
    status 200
    if @folio.entries.count < 1
      status 404
    else
      status 200
      slim :project, {:layout => false}
    end
  end

  get '/quote' do
    @quote = Quote.all.sample
    return :project, {:layout => false}
  end

  get '/search/:search' do
    @folio = search params[:search]
    slim :folio, {:layout => false}
  end

  post '/search' do
    @folio = search params[:search]
    if @folio.entries.count < 1
      status 404
      slim :'404', {:layout => false}
    else
      status 200
      slim :project, {:layout => false}
    end
  end

  # INTERFACE #
  get '/stylesheets/:name.css' do
    content_type 'text/css', :charset => 'utf-8'
    scss(:"../sass/#{params[:name]}")
  end

  get '/js/run.js' do
    content_type "text/javascript", :charset => 'utf-8'
    coffee :run
  end

  not_found{ slim :'404'}
  error{ @error = request.env['sinatra_error']; slim :'500'}

end

def github
  temp = HTTParty.get('https://api.github.com/users/markpoon/repos', :query => {:sort => "created"})
  temp.collect {|a| [a["name"], a["description"], a["html_url"]]}
end
class Folio
  include Mongoid::Document
  field :title, type: String
  field :thumb, type: Array
  field :thumburl, type: Array
  field :paragraph, type: Array
  field :updated, type: DateTime, default: nil
  field :created, type: DateTime, default: ->{ Time.now }
  field :tag, type: Array, default: nil
  validates_presence_of :title, :thumb, :paragraph, :tag, :created
  validates_uniqueness_of :title
end

class Quote
  include Mongoid::Document
  field :quotation, type: String
  field :author, type: String
  validates_presence_of :quotation, :author
  validates_uniqueness_of :quotation
end

require 'sinatra/base'
if settings.development?
  require 'sinatra/reloader'
  require 'pry'
end

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
  set :app_file, __FILE__
  set :root, File.dirname(__FILE__)
  set :views, 'views'
  set :public_folder, 'static'
  set :haml, {:format => :html5}
  Mongoid.load! "config/mongoid.yml"

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

  get "/?" do
    @folio = Folio.desc(:created).limit(3).entries
    @quote = Quote.all.sample
    status 200
    haml :index
  end
  get '/folio' do
    @folio = Folio.desc(:created).limit(3).skip(params["skip"]||0)
    @quote = Quote.all.sample
    status 200
    if @folio.entries.count < 1
      status 404
    else
      status 200
      haml :'folio_entry', {:layout => false}
    end
  end

  get '/search/:search' do
    @folio = search params[:search]
    haml :'folio_entry', {:layout => false}
  end

  post '/search' do
    @folio = search params[:search]
    if @folio.entries.count < 1
      status 404
      haml :'404', {:layout => false}
    else
      status 200
      haml :'folio_entry', {:layout => false}
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

  not_found{ haml :'404'}
  error{ @error = request.env['sinatra_error']; haml :'500'}
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

__END__

@@layout
!!! 5
%html
  %head
    %meta{name: 'ROBOTS', content: 'NOINDEX, NOFOLLOW'}
    %meta{name: "viewport", content: "width=device-width, user-scalable=yes, minimum-scale=1.0, maximum-scale=4.2"}
    %title="Mark Poon, Developing Ruby APIs, Designing for iOS and Web."
    %link{href:"/stylesheets/animation.css", rel:"stylesheet"}
    %link{href: "/stylesheets/screen.css", rel: "stylesheet"}
  %body
    = yield
  %script{:src => "http://cdn.lovely.io/core.js"}
  %script{:src => "/js/run.js"}

@@index
.row{style:"padding:0px"}
  %h1>Mark Poon
  .header
    Building Restful APIs for the Web and iOS.
    %div
      %a.lui-icon-envelope-alt{href: 'mailto:markpoon@me.com', title: "Contact Me"}Get In Touch
.row{style:"padding:0px"}
  =haml :search, {:layout => false}
.entries
  =haml :folio_entry
%button{:id=>"more"} Load Some More Examples
%button{:id=>"browse"} Browse Through Everything Instead

@@folio_entry
-@folio.each do |folio|
  .row.entry{id: folio.title}
    .caption
      %div
        %h2=folio.title.gsub('_', ' ')
        =folio.created.strftime("Created: %b, %Y")
      .captiontags
        - folio.tag.each do |t|
          %td{style: "width:auto;", nowrap: "nowrap"}
            .tag
              %a{href: "/search/#{t}"}>=t
    %figure
      -if check(folio.thumburl[0])
        %a{href: folio.thumburl[0], target: '_blank'}
          %img{src: folio.thumb[0], alt: folio.title}
      -else
        %a{href: folio.thumburl[0], "data-zoom" => ''}
          %img{src: folio.thumb[0], alt: folio.title}
    .paragraph
      =folio.paragraph[0]
    -if folio.thumburl.count > 1
      -folio.thumburl.each_index do |i|
        -unless i == 0          
          %figure.thumb
            -if check(folio.thumburl[i])
              %a{href: folio.thumburl[i], target: '_blank'}
                %img{src: folio.thumb[i], alt: folio.title}
            -else
              %a{href: folio.thumburl[i], "data-zoom" => ''}
                %img{src: folio.thumb[i], alt: folio.title}
          -if i%3 == 0
            .row.paragraph
              =folio.paragraph[i/3]
%hr
.row.quote
  =@quote.quotation
.row.author
  =@quote.author
%hr{style: "margin-bottom: 125px;"}

@@search
%form{:id => "search", :action=>"/search", :method=>"post"}
  .searcharea.box
    %input.box{:type => "text", :name => "search", :placeholder => "What sort of examples are you looking for?"}

@@404
.warning
  %h1 404
  %hr 
  Apologies, there were no results found for your query.
  %hr

@@500
.warning
  %h1 500
  %hr
  %p @error.message
  %hr


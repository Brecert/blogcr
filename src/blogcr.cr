require "./blogcr/*"
require "markdown"
require "tempfile"
require "router"
require "html"
require "yaml"
require "json"
require "ecr"

# posts = {
#   "example": {
#     "author":      "John Doe",
#     "author_id":   "0",
#     "date":        "Time.now.epoch",
#     "title":       "Example Post",
#     "description": "An example post put here to show off how this should work",
#     "body":        "A very long *markdown* body full with <b> Html </b> tags",
#   },
# }

# File.open("posts.yml", "w") { |f| posts.to_yaml(f) }

posts = YAML.parse(File.read("./posts.yml"))

class Post
  property id, author, date, title, description, content

  def initialize(@id : String | Nil,
                 @author : String = "Unknown",
                 @date : Time = Time.utc_now,
                 @title : String = "Untitled",
                 @description : String = "",
                 @content : String = "")
  end

  def to_h
    {
      "#{@id}" => {
        author:      @author,
        date:        @date,
        title:       @title,
        description: @description,
        content:     @content,
      },
    }
  end

  macro map(key, value)
    yaml.scalar {{key}}; yaml.scalar {{value}}
  end

  def to_json
    output = JSON.build do |json|
      json.object do
        json.scalar @id
        json.object do
          json.field "author", @author
          json.field "date", @date
          json.field "title", @title
          json.field "description", @description
          json.field "content", @content
        end
      end
    end
    output
  end

  def to_yaml
    output = YAML.build do |yaml|
      yaml.mapping do
        yaml.scalar @id
        yaml.mapping do
          map("author", @author)
          map("date", @date)
          map("title", @title)
          map("description", @description)
          map("content", @content)
        end
      end
    end
    output
  end

  macro mappy(name)
    name = @{{name}}
  end

  def to_local
    mappy(author)
    mappy(date)
    mappy(title)
    mappy(description)
    mappy(content)
  end

  def to_html
    self.to_local
    page = IO::Memory.new
    ECR.embed "./src/templates/post.md", page
    Markdown.to_html(HTML.escape(page.to_s))
  end
end

# p x = Post.new(id: "no").to_h.merge!(Post.new(id: "ha").to_h)

class EcrPost
  id : String | Nil
  author : String | Nil
  date : String | Nil
  title : String | Nil
  description : String | Nil
  content : String | Nil

  def initialize(post)
    author = post.author
    date = post.date.to_s
    title = post.title
    description = post.description
    content = post.content

    @page = IO::Memory.new
    ECR.embed "./src/templates/post.md", @page
  end

  def render
    Markdown.to_html(HTML.escape(@page.to_s))
  end
end

class WebServer
  # Add Router functions to WebServer
  include Router

  def initialize(posts : Array(Post))
    @posts = posts
  end

  def draw_routes
    # Define index access for this server
    # We just print a result "Hello router.cr!" here
    get "/" do |ctx, params|
      ctx.response.print "No"
      ctx
    end

    # You can get path parameter form `params` param
    # It's a Hash of String => String
    get "/post/:id" do |ctx, params|
      @posts.each do |post|
        if post.id == params["id"]
          @found = true
          ctx.response.content_type = "text/html; charset=utf-8"
          # page = EcrPost.new post
          ctx.response.puts post.to_html
          break
        end
      end
      if @found != true
        ctx.response.respond_with_error(message = "Not Found", code = 404)
      end
      ctx
    end

    # TODO: Add proper auth.
    post "/auth/:uuid/post" do |ctx, params|
      # Temp for auth... :I
      if "uuid_hash_or_something" === "uuid_hash_or_something"
        post = Post.new(id: "Untitled")

        if ctx.request.body
          HTTP::FormData.parse(ctx.request) do |part|
            case part.name
            when "title"
              post.title = part.body.gets_to_end
            when "description"
              post.description = part.body.gets_to_end
            when "content"
              post.content = part.body.gets_to_end
            when "author"
              post.author = part.body.gets_to_end
            when "id"
              post.id = part.body.gets_to_end
              # when "date"
              #   post.date = Time.epoch part.body.gets_to_end
            end
          end

          i = 1
          @posts.each do |existing_post|
            if existing_post.id === post.id
              post.id = "#{post.id}-#{i}"
              i += 1
            end
          end

          @posts << post
          ctx.response.print post.to_json
        end
      end
      ctx
    end
  end

  def run
    server = HTTP::Server.new(3000, route_handler)
    puts "Running Server on Port #{server.port}"
    server.listen
  end
end

temp = [Post.new(id: "example", author: "Bree", title: "Hello world!", description: "My first post!", content: "**Hello World!**, *Hello World!*, Hello World!")]
temp << Post.new(id: "example-1", author: "Daggersdie", title: "No", description: "No", content: "# NO")
temp << Post.new(id: "meep", author: "Meep", title: "I'm a title", description: "Haha jokes", content: "_I'm italic_")

web_server = WebServer.new(temp)
web_server.draw_routes
web_server.run

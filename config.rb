# Require any additional compass plugins here.
require "susy"

http_path = "/"
css_dir = "static/stylesheets"
http_stylesheets_path = "/stylesheets"
sass_dir = "views/stylesheets"
images_dir = "public/images"
http_images_path = "/public/images"
javascripts_dir = "javascripts"

# You can select your preferred output style here (can be overridden via the command line):
# output_style = :expanded or :nested or :compact or :compressed
environment = :production

relative_assets = true



# If you prefer the indented syntax, you might want to regenerate this
# project again passing --syntax sass, or you can uncomment this:
# preferred_syntax = :sass
# and then run:
# sass-convert -R --from scss --to sass views/stylesheets scss && rm -rf sass && mv scss sass

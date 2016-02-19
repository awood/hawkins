# Hawkins
Hawkins is a [Jekyll](http://jekyllrb.com) 3 plugin that incorporates
[LiveReload](http://www.livereload.com) into the Jekyll "serve" process.

## How to Use
Add the following into your `Gemfile`

```
group :jekyll_plugins do
  gem 'hawkins', :git => "https://github.com/awood/hawkins", :branch => 'jekyll3'
end
```

Then run `jekyll liveserve` to serve your files.  The `liveserve` commands takes
all the arguments that `serve` does but with a few extras that allow you to
specify the port that LiveReload runs on or how long LiveReload will wait.  See
the --help for more information.

## How It Works
Hawkins uses a WEBrick servlet that automatically inserts a script tag into a
page's `head` section.  The script tag points to a LiveReload server running on
the same host (by default on port 35729).  That server serves `livereload.js`
over HTTP and also acts as a WebSockets server that speaks the LiveReload
protocol.

If you don't have a browser that implements WebSockets, you can use the
`--swf` option that will have Hawkins load a Flash file that implements
WebSockets.

## Thanks
Lots of thanks to [guard-livereload](https://github.com/guard/guard-livereload)
and [rack-livereload](https://github.com/johnbintz/rack-livereload) which
provided a lot of the code and ideas that Hawkins uses.  And of course thanks to
the Jekyll team for providing an outstanding product.

## Copyright
Copyright (c) 2014 Alex Wood. See LICENSE.txt for further details.


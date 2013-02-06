request = require 'request'
qs = require 'querystring'
q = require 'q'
http = require 'q-io/http'
url = require 'url'
path = require 'path'
_s = require 'underscore.string'

class exports.Markdown
  HOST: 'fuckyeahmarkdown.com'
  PATH: '/go/'

  # Converts `html` to Markdown using the fuckyeahmarkdown.com web service.
  fromHTML: (html) ->
    body = 'html=' + encodeURIComponent(html)
    deferred = q.defer()
    http.request({
      method: 'POST'
      host: @HOST
      path: @PATH
      body: [ body ]
      headers: {
        'Content-type': 'application/x-www-form-urlencoded'
        'Content-length': body.length
      }
    })
    .then (response) =>
      q.when response.body.read(), (buffer) ->
        deferred.resolve buffer.toString()
    .done()
    return deferred.promise

  # For normal links we check whether the URL starts with the provided prefix.
  # If so this is a local link and we replace it with the appropriate relative
  # path to the page (which is just the name of the document).
  #
  # The converter outputs hyperlinked images as: [![][20]][20].
  # The correct output would be [![][19][20], where 19 is the index of the
  # image URL (see below) and 20 is the index of the URL that the image
  # hyperlinks to.
  #
  # The image URLs at the bottom of the document should be prefaced by the
  # appropriate index:
  #
  # ...
  # [18] http://some/url/here
  # [19] http://host/path/to/the/image.png
  # [20] http://another/url/here
  #
  # Instead, the index for the image is omitted:
  #
  # [18] http://some/url/here
  # [] http://host/path/to/the/image.png
  # [20] http://another/url/here
  #
  # We add the correct index and change the image URL to a relative path on disk
  # (which is a bit of a hack and should be made more generic).
  #
  # What we probably want here is a CoffeeScript or JavaScript implementation of an
  # HTML -> Markdown converter that isn't buggy, so we can get rid of this function entirely.
  fixLinks: (markdown, projectPrefix) ->
    console.log projectPrefix
    images = []
    links = []
    fixed = []
    index = 0
    for line in markdown.split '\n'
      # Is this an indexed URL?
      match = line.match /^ \[(\d*)\]: (.*)/
      if match
        # If so, do we have an index?
        if match[1]
          console.log 'BAZ'
          index = match[1]
          link = match[2]
          console.log 'BAR: ' + link
          if _s.startsWith link, projectPrefix
            # Looks like a link to a local wiki page so convert the URL.
            console.log 'FOO'
            console.log links[index]
            line = " [#{index}]: #{links[index]}"
          fixed.push line
        else
          # If not, add the correct index.
          index++
          match = line.match /\[\]: (.*)/
          imageURL = match[1]
          parsedURL = url.parse imageURL
          # Remove the query string.
          imageURL = "#{parsedURL.protocol}//#{parsedURL.host}#{parsedURL.pathname}"
          basename = (path.basename parsedURL.pathname)
          filename = decodeURIComponent("images/#{basename}").replace /\s/g, '-'
          images.push { remoteURL: imageURL, localPath: filename }
          # Replace the image URL with the relative path.
          fixed.push " [#{index}]: #{filename}"
      else
        # This isn't an indexed URL, so check if there is a hyperlined image.
        match = line.match /(.*)\[!\[\]\[\d+\]\]\[(\d+)\](.*)/
        if match
          # If there is, fix it so that the index of the image is one less than the
          # index of the hyperlink.
          fixed.push "#{match[1]}[![][#{match[2]-1}]][#{match[2]}]#{match[3]}"
        else
          # Check for a normal link with format "[name][index]".
          matches = line.match /\[[^\]]+\]\[\d+\]/g
          if matches
            for str in matches
              match = str.match /\[([^\]]+)\]\[(\d+)\]/
              # Remember the link name for when we output the links later.
              console.log match
              links[match[2]] = encodeURIComponent match[1]
          fixed.push line
    return {
      markdown: fixed.join "\n"
      images: images
    }

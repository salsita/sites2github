xml2js = require 'xml2js'
request = require 'request'
qs = require 'querystring'
_ = require 'underscore'
_s = require 'underscore.string'
q = require 'q'
http = require 'q-io/http'
fs = require 'q-io/fs'
url = require 'url'

class exports.GoogleSite
  authToken: null

  constructor: (@domain, @site) ->

  CLIENT_LOGIN_HOST: 'www.google.com'
  SITES_DATA_API_HOST: 'sites.google.com'
  CLIENT_LOGIN_PATH: '/accounts/ClientLogin'
  SITES_DATA_API_PATH: '/feeds/content/'

  # Calls the Google web service to get an authentication token.
  # We pass the user name and password in as POST data.
  # The response looks like this:
  #
  # SID=[sid]
  # LSID=[lsid]
  # Auth=[authentication token]
  #
  # We only need to extract the authentication token.

  authenticate: (username, password) ->
    if typeof(password) == "undefined"
      # No password means we have been passed an authentication token
      return q.resolve (@authToken = username)

    params = {
      Email: username
      Passwd: password
      accountType: 'GOOGLE'
      source: 'sites2github'
      service: 'jotspot'
    }
    body = qs.stringify params
    return http.request({
      method: 'POST'
      ssl: true
      host: @CLIENT_LOGIN_HOST
      path: @CLIENT_LOGIN_PATH
      body: [ body ]
      headers: {
        'Content-type' : 'application/x-www-form-urlencoded'
        'Content-length': body.length
      }
    })
    .then (response) =>
      if response.status != 200
        throw 'HTTP failed with code ' + response.status
      q.when response.body.read(), (buffer) =>
        body = buffer.toString()
        authMatch = body.match /\nAuth=(.*)/
        if authMatch
          @authToken = authMatch[1]
          return @authToken
        else
          throw 'Unexpected response'

  # Make a request to the Google Sites Data API.
  # `what` can either be the fully qualified URL that we want to retrieve
  # or a query string to add to the default URL.
  # The optional `where` parameter is a file path. If specified, the
  # document that is retrieved is written to disk at this path.
  apiRequest: (what, where) ->
    if _s.startsWith what, 'http'
      parsedURL = url.parse what
    else
      parsedURL = {
        host: @SITES_DATA_API_HOST
        path: @SITES_DATA_API_PATH + @domain + '/' + @site + "?#{what}"
      }
    headers = { Authorization: 'GoogleLogin auth=' + @authToken }
    deferred = q.defer()
    http.request({
      method: 'GET'
      ssl: true
      host: parsedURL.host
      path: parsedURL.path
      headers: headers
    })
    .then (response) =>
      q.when response.body.read(), (buffer) ->
        if where
          deferred.resolve fs.write(where, buffer)
        else
          deferred.resolve buffer.toString()
    .done()
    return deferred.promise

  # Returns a list of pages underneath the page with the specified `id`.
  getChildPages: (parentURL) ->
    deferred = q.defer()
    id = (parentURL.match /(\d+)$/)[1]
    @apiRequest("parent=#{id}")
    .then (xml) ->
      parser = new xml2js.Parser()
      feed = q.nfcall parser.parseString, xml
    .then (result) =>
      promises = []
      if result.feed.entry
        pages = _.reduce result.feed.entry, (obj, val) =>
          pageURL = val.id[0]
          obj[val.title[0]] = { url: pageURL }
          qSubPages = @getChildPages pageURL
          qSubPages.then (subpages) ->
            obj[val.title[0]].subpages = subpages
          promises.push qSubPages
          return obj
        , {}
      else
        pages = []
      q.all(promises).then ->
        deferred.resolve pages
    .done()
    return deferred.promise

  # Returns a list of pages underneath `parentPath`.
  listPages: (parentPath) ->
    deferred = q.defer()
    @apiRequest("path=#{parentPath}")
    .then (xml) =>
      parser = new xml2js.Parser()
      return q.nfcall parser.parseString, xml
    .then (result) =>
      parentURL = result.feed.entry[0].id[0]
      @getChildPages parentURL
    .then (pages) ->
      deferred.resolve pages
    .done()
    return deferred.promise

  # Retrieves the document at the specified `url` as text.
  getText: (url) ->
    return @apiRequest url

  # Retrieves the document at the specified `url` and writes it
  # to disk at `path`.
  getFile: (url, path) ->
    deferred = q.defer()
    @apiRequest(url, path)
    .then(() ->
      deferred.resolve path
    )
    return deferred.promise

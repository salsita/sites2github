q = require 'q'
commander = require './commander-wrapper'
DOMParser = (require 'xmldom').DOMParser
XMLSerializer = (require 'xmldom').XMLSerializer
GoogleSite = (require './gsites').GoogleSite
Markdown = (require './markdown').Markdown
Git = (require './git').Git
fs = require 'q-io/fs'
url = require 'url'
path = require 'path'
_ = require 'underscore'
_s = require 'underscore.string'

NO_CONTENT_EXCEPTION = 'No content'

SITE_DOMAIN = 'salsitasoft.com'
SITE_NAME = 'wiki'
GITHUB_REMOTE_URL = 'git@github.com:salsita/'
SETTINGS_PATH = 'settings.json'

settings = {}

readSettings = ->
  deferred = q.defer()
  fs.exists(SETTINGS_PATH)
  .then (exists) ->
    if !exists
      deferred.resolve {}
    else
      fs.read(SETTINGS_PATH)
      .then (content) ->
        deferred.resolve JSON.parse(content)
      .done()
  .done()
  return deferred.promise

site = new GoogleSite SITE_DOMAIN, SITE_NAME
readSettings()
.then (value) ->
  settings = value
  googleAuthentication(site, settings)
.then ->
  writeSettings(settings)
.then ->
  commander.prompt('Project: ')
.then (project) ->
  projects = project.split ' '
  sites_project = projects[0]
  git_project = if projects.length > 1 then projects[1] else projects[0]
  site.listPages('/projects/' + sites_project)
  .then (pages) ->
    selectPage(pages)
  .then (pages) ->
    if pages
      repo = new Git "#{GITHUB_REMOTE_URL}#{git_project}.wiki.git"
      repo.exists()
      .then (exists) ->
        if !exists
          repo.clone()
        else
          return q.resolve true
      .then ->
        if !_.isArray pages
          pages = [ pages ]
        promises = []
        for page in pages
          promises.push(transferPage site, repo, page.name, page.url)
        q.spread promises, ->
          names = _.pluck(pages, 'name').join ', '
          console.log names
          repo.commit "Migrated #{names} from Google Sites"
        .then ->
          repo.push()
.then ->
  console.log 'All done'
.fail (error) ->
  console.error error.stack
  console.error error
.finally ->
  process.exit(0)
.done()

googleAuthentication = (site, settings) ->
  deferred = q.defer()
  if "GoogleAuth" of settings
    deferred.resolve site.authenticate(settings.GoogleAuth)
  else
    commander.prompt('Username: ')
    .then (username) ->
      commander.password('Password: ')
      .then (password) ->
        site.authenticate(username, password)
      .then ->
        settings.GoogleAuth = site.authToken
        q.resolve true
      .then ->
        deferred.resolve()
      .done()
  return deferred.promise

writeSettings = (settings) ->
  return fs.write SETTINGS_PATH, JSON.stringify(settings)

createImagesFolder = (imagesPath) ->
  fs.exists(imagesPath)
  .then (exists) ->
    if !exists
      return fs.makeDirectory(imagesPath)
    else
      return q.resolve true

transferPage = (site, repo, pageName, pageURL) ->
  console.log "Transferring #{pageName}"
  deferred = q.defer()
  site.getText(pageURL)
  .then (xml) ->
    doc = new DOMParser().parseFromString xml
    contentElement = (doc.getElementsByTagName 'content').item(0)
    if !contentElement then throw NO_CONTENT_EXCEPTION
    contentHTML = new XMLSerializer().serializeToString contentElement
    markdown = new Markdown
    markdown.fromHTML(contentHTML)
    .then (md) ->
      # The Markdown converter doesn't handle images properly so we fix them ourselves.
      markdown.fixImages(md)
  .then (result) ->
    # Now we have the markdown and an array of images.
    console.log "Saving markdown for #{pageName}"
    filename = "#{repo.rootPath}/#{pageName.replace /[:\/]/g, ''}.md"
    fs.write(filename, result.markdown)
    .then ->
      repo.add filename
    .then ->
      console.log "Getting images for #{pageName}"
      imagesPath = "#{repo.rootPath}/images"
      q.when (result.images.length == 0 || createImagesFolder(imagesPath)), ->
        promises = []
        for image in result.images
          # Remove the fragment from the URL, if any
          parsed = url.parse image.remoteURL
          remoteURL = "#{parsed.protocol}//#{parsed.host}#{parsed.pathname}"
          console.log "Copying #{remoteURL} to #{repo.rootPath}/#{image.localPath}"
          promise = site.getFile(remoteURL, "#{repo.rootPath}/#{image.localPath}")
          promises.push promise
        q.spread promises, ->
          for filePath in arguments
            repo.add filePath
          deferred.resolve()
  .fail (error) ->
    if error == NO_CONTENT_EXCEPTION
      # This is expected so we just return
      deferred.resolve()
    else
      # Rethrow so it is handled by the caller
      throw error
  .done()
  return deferred.promise

displayPages = (pages, depth, results) ->
  for name of pages
    index = results.length+1
    console.log "[#{index}] #{_s.repeat('.', depth)}#{name}"
    results.push { name: name, url: pages[name].url }
    displayPages pages[name].subpages, depth+2, results

selectPage = (pages) ->
  results = []
  deferred = q.defer()
  displayPages pages, 0, results
  commander.prompt('Page (or "a" for all): ')
  .then (pageNumber) ->
    if pageNumber == 'a'
      deferred.resolve ({ name: result.name, url: result.url } for result in results)
    else if _s.isBlank pageNumber
      deferred.resolve null # null means we're done
    else
      result = results[pageNumber-1]
      deferred.resolve { name: result.name, url: result.url }
  .done()
  return deferred.promise

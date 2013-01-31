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

SITE_DOMAIN = 'salsitasoft.com'
SITE_NAME = 'wiki'
GITHUB_REMOTE_URL = 'git@github.com:salsita/'

site = null
commander.prompt('Username: ')
.then (username) ->
  commander.password('Password: ')
  .then (password) ->
    site = new GoogleSite SITE_DOMAIN, SITE_NAME
    site.authenticate(username, password)
    .then () ->
      commander.prompt('Project: ')
.then (project) ->
  site.listPages('/projects/' + project)
  .then (pages) ->
    selectPage(pages)
  .then (page) ->
    repo = new Git "#{GITHUB_REMOTE_URL}#{project}.wiki.git"
    fs.exists(repo.rootPath)
    .then (exists) ->
      if !exists
        repo.clone()
      else
        return q.resolve true
    .then () ->
      transferPage(site, repo, page.name, page.url)
    .then () ->
      repo.commit "Migrated #{page.name} from Google Sites"
    .then () ->
      repo.push()
.then () ->
  console.log 'All done'
.fail (error) ->
  console.error error.stack
  console.error error
.finally () ->
  process.exit(0)
.done()

createImagesFolder = (imagesPath) ->
  fs.exists(imagesPath)
  .then (exists) ->
    if !exists
      return fs.makeDirectory(imagesPath)
    else
      return q.resolve true

transferPage = (site, repo, pageName, pageURL) ->
  deferred = q.defer()
  site.getText(pageURL)
  .then (xml) ->
    doc = new DOMParser().parseFromString xml
    contentElement = (doc.getElementsByTagName 'content').item(0)
    contentHTML = new XMLSerializer().serializeToString contentElement
    markdown = new Markdown
    markdown.fromHTML(contentHTML)
    .then (md) ->
      # The Markdown converter doesn't handle images properly so we fix them ourselves.
      markdown.fixImages(md)
  .then (result) ->
    # Now we have the markdown and an array of images.
    console.log 'Saving markdown'
    filename = "#{repo.rootPath}/#{pageName}.md"
    console.log(filename)
    fs.write(filename, result.markdown)
    .then () ->
      repo.add filename
    .then () ->
      console.log 'Getting images'
      imagesPath = "#{repo.rootPath}/images"
      q.when (result.images.length == 0 || createImagesFolder(imagesPath)), () ->
        promises = []
        for image in result.images
          # Remove the fragment from the URL, if any
          parsed = url.parse image.remoteURL
          remoteURL = "#{parsed.protocol}//#{parsed.host}#{parsed.pathname}"
          console.log "Copying #{remoteURL} to #{repo.rootPath}/#{image.localPath}"
          promise = site.getFile(remoteURL, "#{repo.rootPath}/#{image.localPath}")
          promises.push promise
        q.spread promises, () ->
          for filePath in arguments
            repo.add filePath
          deferred.resolve()
  .done()
  return deferred.promise

selectPage = (pages) ->
  names = []
  deferred = q.defer()
  for name of pages
    index = names.length+1
    console.log '[' + index + '] ' + name
    names.push name
  commander.prompt('Page: ')
  .then (pageNumber) ->
    name = names[pageNumber-1]
    deferred.resolve { name: name, url: pages[name] }
  .done()
  return deferred.promise

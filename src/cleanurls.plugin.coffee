# Export Plugin
module.exports = (BasePlugin) ->
	# Define Plugin
	class CleanUrlsPlugin extends BasePlugin
		# Name
		name: 'cleanurls'

		# Config
		config:
			getRedirectTemplate: (document) ->
				"""
				<!DOCTYPE html>
				<html>
					<head>
						<title>#{document.get('title') or 'Redirect'}</title>
						<meta http-equiv="REFRESH" content="0;url=#{document.get('url')}">
					</head>
					<body>
						This page has moved. You will be automatically redirected to its new location. If you aren't forwarded to the new page, <a href="#{document.get('url')}">click here</a>.
					</body>
				</html>
				"""

		# Clean URLs for Document
		cleanUrlsForDocument: (document) =>
			# Prepare
			url = document.get('url')
			pathUtil = require('path')

			# Index URL
			if /index\.html$/i.test(url)
				relativeDirUrl = pathUtil.dirname(url)
				document.setUrl(relativeDirUrl)

			# Create Extensionless URL
			else if /\.html$/i.test(url)
				relativeBaseUrl = url.replace(/\.html$/,'')
				document.setUrl(relativeBaseUrl)
				document.addUrl(relativeBaseUrl+'/')

			# Done
			document

		# Collections have been created, so listen for html files to update the urls
		renderBefore: (opts) ->
			# Prepare
			docpad = @docpad
			database = docpad.getCollection('html')

			# When we get a new document, update its url
			docpad.log 'debug', 'Applying clean urls'
			database.forEach @cleanUrlsForDocument
			docpad.log 'debug', 'Applied clean urls'

			# All done
			@

		# Write After
		writeAfter: (opts,next) ->
			# Prepare
			config = @config
			docpad = @docpad
			docpadConfig = docpad.getConfig()
			database = docpad.getCollection('html')
			balUtil = require('bal-util')
			pathUtil = require('path')
			getCleanOutPathFromUrl = (url) ->
				url = url.replace(/\/+$/,'')
				if /index.html$/.test(url)
					pathUtil.join(docpadConfig.outPath, url)
				else
					pathUtil.join(docpadConfig.outPath, url.replace(/\.html$/,'')+'/index.html')

			# Static
			if 'static' in docpad.getEnvironments()
				# Tasks
				docpad.log 'debug', 'Writing static clean url files'
				tasks = new balUtil.Group (err) ->
					docpad.log 'debug', 'Wrote static clean url files'
					return next(err)
				addWriteTask = (outPath, outContent, encoding) ->
					tasks.push (complete) ->
						return balUtil.writeFile(outPath, outContent, encoding, complete)

				# Cycle
				database.forEach (document) ->
					# Check
					return  if document.get('write') is false or document.get('ignore') is true or document.get('render') is false

					# Prepare
					encoding = document.get('encoding')
					primaryUrl = document.get('url')
					primaryUrlOutPath = getCleanOutPathFromUrl(primaryUrl)
					primaryOutPath = document.get('outPath')
					urls = document.get('urls')
					redirectContent = config.getRedirectTemplate(document)
					redirectOutPaths = []

					# If the primary out path is not our desired primary url out path
					# then update it with the redirect template
					# and update our primaru url out path with the actual content
					if primaryUrlOutPath isnt primaryOutPath
						addWriteTask(primaryUrlOutPath, document.getOutContent(), encoding)
						redirectOutPaths.push(primaryOutPath)

					# Cycle through the other urls
					for url in urls
						redirectOutPath = getCleanOutPathFromUrl(url)
						if (redirectOutPath in redirectOutPaths) is false and redirectOutPath isnt primaryUrlOutPath
							redirectOutPaths.push(redirectOutPath)
					for redirectOutPath in redirectOutPaths
						addWriteTask(redirectOutPath, redirectContent, encoding)

				# Fire
				tasks.async()

			# Development
			else
				next()

			# Chain
			@


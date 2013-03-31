usage = '''
This module spawns a `git clone` for all of a user's git repositories
$ echo "https://github.com/markmontymark" > urls.txt
$ node.io git-clone-all.coffee < urls.txt
'''

nodeio = require 'node.io'
exec   = require('child_process').exec
spawn  = require('child_process').spawn

options = max: 10, take:10

tab = '?tab=repositories'
gitsuffix = '.git'

class GitCloneAll extends nodeio.JobClass
	run: (url) ->
		@getHtml(url + tab, (err, $) ->
			repos = []
			console.log "match on #{url}"
			githost = ("" + url).match("^(.*[^/])/")
			githost = githost[0].replace(/\/$/,'') if githost? and Object::toString.call(githost) is '[object Array]'
			console.error "githost is #{githost}"
			$('h3 a').each((node)->
				repo_url = node?.attribs?.href
				console.log repo_url
				repos.push(githost + repo_url) if repo_url
				return true
			)
			#console.log results
			@emit repos
		)

	output: (repos) ->
		for repo in repos
			console.error "git clone #{repo + gitsuffix}"
			child = spawn('git',['clone',"#{repo + gitsuffix}"],{env:process.env})
		return null

class UsageDetails extends nodeio.JobClass
	input: ->
		@status usage
		@exit()

@class = GitCloneAll
@job = {
    count: new GitCloneAll(options)
    help: new UsageDetails()
}
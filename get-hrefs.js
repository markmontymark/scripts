#!/usr/bin/env node

"use strict";

var http = require('http');
var fs = require('fs');

var baseurl = "http://www.grymoire.com/Unix/";
var basedir;
crawl(process.argv[2],process.argv[3],/['"](Scripts\/[^'"]+\.(?:sed|sh))['"]/ig);

function composeIfDefined(func1, func2) {
	return function() {
		var result = func2.apply(null, arguments);
		if(result){
			return func1(result);
		}
	};
}

function crawl(url,dir,matcher){
	basedir = dir;
	fs.mkdirSync(dir);
	var chunks = [];
	http.get(url,function(res){
		res.on('data', function (chunk) {
			chunks.push( chunk.toString('utf-8'));
		});
		res.on('end',function(){
			var html = chunks.join('');
			var matches;
			while( (matches = matcher.exec( html )) !== null){
				matches.forEach(findScript);
			}
		});
	});
}

function rxIgnoreFullMatchString(item,i /*,list*/){
	if(i === 0){
		return null;
	}
	return item;
}

var findScript = composeIfDefined(function(item /*,i,list*/ ){
	http.get(baseurl + item, (function(item){
		return function(res){
			var chunks = [];
			res.on('data',function(chunk){
				chunks.push( chunk.toString('utf-8') );
			});
			res.on('end',function(){
				var filename = item.substring(item.lastIndexOf('/') + 1);
				fs.writeFile(basedir + '/' + filename,chunks.join(''));
			});
		};})(item));
	},
	rxIgnoreFullMatchString);


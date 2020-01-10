import {createConnection, TextDocuments} from 'vscode-languageserver'
import {DiagnosticSeverity} from 'vscode-languageserver-types'
import {URI} from 'vscode-uri'
import {LanguageServer} from './LanguageServer'

var fs = require 'fs'
var ts = require 'typescript'

var imbac = require('imba/dist/compiler.js')
var sm = require("source-map")

var connection = process.argv.length <= 2 ? createConnection(process.stdin, process.stdout) : createConnection()

console.log URI.parse
# Create a simple text document manager. The text document manager
# supports full document sync only
const documents = TextDocuments.new
documents.listen(connection)

var server

var workspaceFolder

documents.onDidOpen do |event|
	# connection.console.log("[Server(${process.pid}) ${workspaceFolder}] Document opened: {event.document.uri}")
	server.onDidOpen(event) if server

documents.onDidChangeContent do |change|
	# console.log "server.onDidChangeContent",change
	# let doc = change.document
	server.onDidChangeContent(change) if server
	return


documents.listen(connection)

connection.onInitialize do |params|
	workspaceFolder = params.rootUri
	connection.console.log("[Server({process.pid}) {workspaceFolder}] Started and initialize received")
	server = LanguageServer.new(connection,documents,params)

	return {
		capabilities: {
			# Tell the client that the server works in FULL text document sync mode
			# TODO(scanf): add support for the remaining below
			textDocumentSync: documents.syncKind,
			completionProvider: {
				resolveProvider: true,
				triggerCharacters: ['.', ':', '<', '"', '/', '@', '*','%']
			},
			signatureHelpProvider: false, # { triggerCharacters: ['('] },
			documentRangeFormattingProvider: false,
			hoverProvider: true,
			documentHighlightProvider: false,
			documentSymbolProvider: true,
			definitionProvider: true,
			referencesProvider: false,
			documentOnTypeFormattingProvider: {
				firstTriggerCharacter: ';',
				moreTriggerCharacter: ['}', '\n']
			}
		}
	}

connection.onDidChangeConfiguration do |change|
	console.log "connection.onDidChangeConfiguration"

connection.onDocumentSymbol do |documentSymbolParms|
	let uri = documentSymbolParms.textDocument.uri
	return []

connection.onDefinition do |event,b|
	let res = server.getDefinitionAtPosition(event.textDocument.uri,event.position)
	# console.log("onDefinition",event,res)
	return res
	# onDefinition(handler: RequestHandler<TextDocumentPositionParams, Definition | DefinitionLink[] | undefined | null, void>): void;	

connection.onHover do |event|
	console.log "onhover",event
	let res = server.getQuickInfoAtPosition(event.textDocument.uri,event.position)
	console.log res
	return res


connection.onCompletion do |event|
	console.log "oncompletion",event
	let res = server.getCompletionsAtPosition(event.textDocument.uri,event.position,event.context)
	console.log res && res.items.slice(0,2)
	# if res
	return res

connection.onCompletionResolve do |item|
	console.log 'completion resolve',item
	console.log 'completion resolve?'
	return server.doResolve(item)
	return null


connection.listen()
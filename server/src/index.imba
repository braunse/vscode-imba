import {createConnection, TextDocuments, Location,TextDocumentSyncKind} from 'vscode-languageserver'
import {LanguageServer} from './LanguageServer'
import {snippets} from './snippets'
# import { TextDocument } from 'vscode-languageserver-textdocument'
import { FullTextDocument } from './FullTextDocument'

let connection = process.argv.length <= 2 ? createConnection(process.stdin, process.stdout) : createConnection()

const documents = new TextDocuments(FullTextDocument)
documents.listen(connection)

let server\LanguageServer

documents.onDidOpen do(event)
	let doc = event.document
	doc.connection = connection
	if doc.tokens
		doc.tokens.connection = connection
	server.onDidOpen(event) if server

documents.onDidChangeContent do(change)
	server.onDidChangeContent(change) if server
	return

documents.onDidSave do(event)
	server.onDidSave(event) if server

connection.onInitialize do(params)
	
	// Could this start a single instance for multiple workspaces?
	# connection.console.log("[Server({process.pid}) {params.rootUri}] Started and initialize received")
	server = new LanguageServer(connection,documents,params)

	return {
		capabilities: {
			textDocumentSync: TextDocumentSyncKind.Incremental
			completionProvider: {
				resolveProvider: true,
				triggerCharacters: ['.', ':', '"', '@','%','\\',"'"]
			},
			# signatureHelpProvider: { triggerCharacters: ['('] },
			signatureHelpProvider: false,
			documentRangeFormattingProvider: false,
			hoverProvider: true,
			documentHighlightProvider: true,
			documentSymbolProvider: true,
			workspaceSymbolProvider: true,
			renameProvider: true,
			semanticTokensProvider: {
				legend: {
					tokenTypes: ['variable']
					tokenModifiers: ['declaration','static']
				}
				rangeProvider: false
				documentProvider: true
			},
			definitionProvider: true,
			referencesProvider: true
		}
	}

connection.onInitialized do(params)
	# console.log 'on initialized',params
	let conf = await connection.workspace.getConfiguration() # ('imba')
	# console.log 'config',conf

	server.start(conf.imba)

	connection.onNotification('onDidRenameFiles') do(event)
		server.onDidRenameFiles(event)
		# console.log 'service.onDidRenameFiles',event
	connection.onNotification('onDidDeleteFiles') do(event)
		server.onDidDeleteFiles(event)

	connection.onNotification('onDidCreateFiles') do(event)
		server.onDidCreateFiles(event)

	connection.onNotification('getProgramDiagnostics') do
		console.log 'getting diagnostics'
		server.emitDiagnostics!

	connection.onNotification('clearProgramProblems') do
		console.log 'clear diagnostics problems'
		server.clearProblems!
		# server.emitDiagnostics!

	connection.onNotification('onDidChangeTextEditorSelection') do(params)
		server.onDidChangeTextEditorSelection(params)
		
	# connection.onDidChangeTextDocument do |event|
	# 	console.log 'onDidChangeTextDocument',event

connection.onDidChangeConfiguration do(change)
	console.log 'onDidChangeConfiguration'
	server.updateConfiguration(change.settings.imba,change.settings)
	# server.config.update(change)

connection.onDocumentSymbol do(event)
	return server ? server.getSymbols(event.textDocument.uri) : []

connection.onWorkspaceSymbol do(event)
	let symbols = server ? server.getWorkspaceSymbols(event) : []
	return symbols.map do(sym)
		{
			kind: sym.kind
			location: sym.location
			name: sym.name
			containerName: sym.containerName
		}


connection.onDefinition do(event)
	# console.log 'onDefinition',event
	let res\any[] = server.getDefinitionAtPosition(event.textDocument.uri,event.position)
	return res

connection.onReferences do(event)
	let res = server.onReferences(event)
	return res

connection.onRequest('semanticTokens') do(params)
	return server.getSemanticTokens(params.uri)

connection.onRequest('increment') do(params)
	if let file = (server and server.getImbaFile(params.uri))
		let sel = params.selections[0]
		return Promise.resolve(file.getAdjustmentEdits(sel.start,params.by))
	return null

connection.onTypeDefinition do(event)
	return undefined

connection.onRenameRequest do(event)
	if server
		return server.onRenameRequest(event)
	return

connection.onHover do(event)
	# console.log "onhover",event
	let res = server.getQuickInfoAtPosition(event.textDocument.uri,event.position)
	# console.log res
	return res


connection.onCompletion do(event)
	let res\any = server.getCompletionsAtPosition(event.textDocument.uri,event.position,event.context)
	if res isa Array
		res = {isIncomplete: false, items: res}
	# console.log res && res.items.slice(0,2)

	return res

connection.onCompletionResolve do(item)
	try
		return server.doResolve(item)
	catch e
		console.log 'onCompletionResolve error',e,item

connection.onDocumentHighlight do(event)
	return []

connection.listen()
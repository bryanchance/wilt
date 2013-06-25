
/*
 * Packge : Wilt
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 04/06/2013
 * Copyright :  S.Hamblett@OSCF
 *
 * The Wilt class provides core functionality for interacting with  CouchDB databases from
 * the browser.
 * 
 * The class itself is based on the excellent Sag PHP CouchDB library and should be
 * familiar to any users of that library.
 * 
 * Ref http://www.saggingcouch.com/ for details
 * 
 * It provides core functionality for the majority of CouchDB operations when using
 * CouchDB purely as a document store. Higher level operations on attachments, 
 * design documents and views are not directly supported but can be used if the client
 * supplies the url to use.
 * 
 * It can be used as a standalone CouchDB library but it is envisaged that it will
 * provide a core library for more advanced and/or specialised CouchDB client libraries to 
 * wrap around.
 * 
 * Results of API calls are returned via completion functions supplied by the client. 
 * Clients then call Wilt API's to determine the outcome of the request. This allows 
 * true async operation throughout the library.
 * 
 * An example of getting a document :-
 * 
 * void completer(){
       
       jsonobject.JsonObject res = wilting.completionResponse;
       /* Check for error */
       try {
         expect(res.error, isFalse);
       } catch(e) {
         
         jsonobject.JsonObject errorResponse = res.jsonCouchResponse;
         String errorText = errorResponse.error;
         String reasonText = errorResponse.reason;
         int statusCode = res.errorCode;
         return;
       }
       
       /* Get the success response*/
       jsonobject.JsonObject successResponse = res.jsonCouchResponse;
       .......
  }
    Wilt wilting = new Wilt("localhost", 
                            "5984",
                            "http://");
   wilting.db = "mydb";
   wilting.resultCompletion = completer;
   wilting.getDocument("myuniqueid");
   .... do other stuff
 
 *
 * Wilt depends on the JSON Object library for its response processing, at the moment this
 * causes problems with internal CouchDB identifiers such as '_rev', '_id' etc. This is overcome
 * by using functionality in the WiltUserUtils class to encode/decode these parameters.
 * 
 * See the API documentation for more details about individual methods, particularly the 
 * WiltNativeHTTPAdapter for the structure of the Wilt completion response.  
 * 
 * A WiltException is thrown if Wilt encounters any method parameter errors.  
 * 
 * Authentication is performed using the login() method. If you are using CouchDB in the 
 * 'Admin Party' mode there is no need to call the login method.
 * 
 * Only basic authentication is currently supported, even then you may hit CORS restrictions.
 * 
 * Cookie authentication is not supported and may never be due to restrictions on getting the 
 * Set-Cookie header from an AJAX request in the browser.
 * 
 * 
 */

part of wilt;

class Wilt {
  
  /* URL constants for CouchDB functions */
  static const String SESSION = "/_session";
  static const String STATS = "/_stats";
  static const String ALLDBS = "/_all_dbs";
  static const String ALLDOCS = "/_all_docs";
  static const String BULKDOCS = "/_bulk_docs";
  static const String UUIDS ="/_uuids";
  
  /**
   * Authentication type constants 
   * 
   * AUTH_BASIC denotes Basic HTTP authentication. 
   * If login is called AUTH_BASIC is set, otherwise it defaults to AUTH_NONE
   * 
   */

  static const String AUTH_BASIC = 'basic';
  static const String AUTH_NONE = 'none';
  
  
  /* Http parameter set */
  String db = null;                 //Database name
  String host = null;              //Host to connect to.
  String port = null;              //Port to connect to.
  String scheme = null;            //Scheme
  WiltNativeHTTPAdapter _httpAdapter;
  
  
  /* Completion function */
  var clientCompletion = null;
  
  /* Authentication, both user and password must be set together */
  String _user = null;                      //Username to authenticate with.
  String _password = null;                  //Password to authenticate with.
  String authenticationType = AUTH_NONE;   //Authentication type
   
 /* Constructor */
  Wilt(this.host,
       this.port,
       this.scheme,
       [this.clientCompletion = null]) {
    
    if ( (host == null) ||
         (port == null)  ||
         (scheme == null )) {
      
      throw new WiltException('Bad construction - some or all required parameters are null');
      
    }
    
    /* Get our HTTP adapter */
    _httpAdapter = new WiltNativeHTTPAdapter(this.clientCompletion);
  }
  
  /* Private */
  
  /**
   *  The internal HTTP request method. This wraps the
   *  HTTP adapter class. 
  */
  void _httpRequest( String method, 
                     String url, 
                     {String data:null, 
                     Map headers:null}) {
    
    
    /* Build the request for the HttpAdapter*/
    Map wiltHeaders = new Map<String,String>();
    wiltHeaders["Accept"] = "application/json";
    if ( headers != null ) wiltHeaders.addAll(headers);
    
    /* Build the URL */
    String wiltUrl = "$scheme$host:$port$url";
    
    /* Check for authentication */
    if ( _user != null ) {
      
      switch (authenticationType) {
                
        case AUTH_BASIC :
          
          String authStringToEncode = "$_user:$_password";
          String encodedAuthString = html.window.btoa(authStringToEncode);
          String authString = "Basic $encodedAuthString";
          wiltHeaders['Authorization'] = authString;
          break;
          
        case AUTH_NONE :
          
          break;
      }
      
    }
    
    /* Execute the request*/
    _httpAdapter.httpRequest(method, 
                             wiltUrl, 
                             data, 
                             wiltHeaders);
    
  }
  

  /**
   * Takes a URL and key/value pair for a URL parameter and adds this
   * to the query parameters of the URL.
   */
  String _setURLParameter( String url, 
                           String key, 
                           String value) {
    
    var originalUrl = Uri.parse(url);
    Map queryParams = originalUrl.queryParameters;
    Map newQueryParams = new  Map<String,String>.from(queryParams);
    newQueryParams[key] = value;
    
    var newUrl = new Uri(scheme:originalUrl.scheme,
                         userInfo:originalUrl.userInfo,
                         host:originalUrl.host,
                         port:originalUrl.port,
                         path:originalUrl.path,
                         queryParameters:newQueryParams);
                         
        
    String returnUrl = newUrl.toString();
    return returnUrl;
    
  }
  
  /**
   * Conditions the URL for use by Wilt and checks for 
   * a valid database by default.
   */
  String _conditionUrl(String url ) {
    
    if( db == null ) {
      
      throw new WiltException('No database specified');
    }
    
    if (  url == null ) return '/';
    
    /* The first char of the URL should be a slash. */
    if( !url.startsWith('/') ) {
     
      url = "/$url";
      
    }
    
    if ( db != null )
      url = "/$db$url";
    
    return url;
    
  }
  
  /* Public */
  
  /* Getters and Setter */
  
  /**
   *  Completion callback 
   */  
  set resultCompletion (var completion )  {
    
    clientCompletion = completion;
    _httpAdapter.completion = completion;
  }
  
  /**
   *  Response getter for completion callbacks 
   */
  jsonobject.JsonObject get completionResponse => _httpAdapter.jsonResponse;
    
  
  /**
   * Basic method where only a URL and a method is passed.
   * Wilt applies no checks to this URL nor does it add the
   * database, the format of this is entirely up to the user.
   * 
   * This can be used for CouchDb functions that are not directly supported by Wilt,
   * e.g views, attachments and design documents.
   */
  void httpRequest(String url,
                   {String method:"GET"} ){
    
    
    /* Perform the request */
    _httpRequest(method,
                 url);
  }
  
  /**
   * Basic methods where a url path is passed. 
   * The database name is appended to the url
   * so only the last part of the url need be supplied.
   */
  
  /**
   * Performs an HTTP GET operation.
   */
  void get( String url) {
        
    url = _conditionUrl(url);
    
    /* Perform the get */
    _httpRequest('GET', 
                  url);
 
    
   }
  
  /**
   * Performs a HTTP HEAD operation.
   */
  head( String url) {
    
    url = _conditionUrl(url);
    
    /* Perform the head */
    _httpRequest('HEAD', 
                 url);
    
   }
  
  /**
   * Performs a HTTP POST operation.
   */
  post( String url, 
        String data,
        [Map headers]) {
    
    url = _conditionUrl(url);
    
    /* Perform the post */
    _httpRequest('POST', 
                 url,
                 data:data,
                 headers:headers);
    
   }
  
  /**
   * Performs a HTTP PUT operation.
   */
  put( String url, 
       String data) {
      
      url = _conditionUrl(url);
    
    /* Perform the put */
    _httpRequest('PUT', 
                url,
                data:data);
    
   }
  
  /**
   * Performs a HTTP DELETE operation.
   *
   */
  delete( String url) {
   
      
     url = _conditionUrl(url);
    
    /* Perform the delete */
    _httpRequest('DELETE', 
                 url);
    
   }
  
  /** 
   * Document oriented functions where a document id/rev is used 
   */
  
  /**
   * Performs an HTTP GET operation for the supplied document id and
   * optional revision. 
   */
  void getDocument( String id, 
                    {String rev}) {
        
    if( id == null ) {
      
      throw new WiltException('getDocument() must have a document id');
    }
    
    String url = id;
    if ( rev != null ) {
      
      url = _setURLParameter(url,
                             'rev',
                             rev);
    }
    
    /* Perform the get */
    get(url);
    
   }
  
  
  /**
   * DELETE's the specified document. Must have a revision.
   */
  void deleteDocument(String id, 
                      String rev) {
  
    if( (id == null) || (rev == null) ) {
    
      throw new WiltException('deleteDocument() expects a document id and a revision.');
    }

    String url = id;
    url = _setURLParameter(url, 
                           'rev', 
                            rev);
    
    /* Perform the delete */
   delete(url);
    
  }
  
  
  /**
   * PUT's to the specified  document.
   */
  void putDocument(String id, 
                   jsonobject.JsonObject document){
    
    
    if( (id == null ) || (document == null)) {
      
      throw new WiltException('putDocument() expects a document id and a document body.');
    }

    String jsonData = null;
    try {
     
      jsonData = json.stringify(document);
    
    } catch(e) {
      
      throw new WiltException('putDocument() cannot stringify the document body, use putDocumentString');
    }
    
    /* Perform the PUT */
    put(id,
       jsonData);
   
    
  }
  
  /**
   * PUT's to the specified  document where the document is supplied as 
   * a JSON string. Must be used if '_id' and or '_rev' are needed.
   */
  void putDocumentString(String id, 
                         String document){
    
    
    if( (id == null ) || (document == null)) {
      
      throw new WiltException('putDocumentString() expects a document id and a document body.');
    }
    
    /* Perform the PUT */
    put(id,
       document);
   
    
  }
  
  /**
   * POST's the specified document.
   * An optional path to the document can be specified.
   */
  void postDocument(jsonobject.JsonObject document, 
                    {String path:null}) {
    
    
    if( document == null ) {
      
      throw new WiltException('postDocument() expects a document body.');
    }
    
    String url = "";
    if ( path != null ) url = "$url/$path";
    
    /* Set the content type for a post */
    Map headers = new Map<String,String>();
    headers["Content-Type"] = "application/json";
    
    String jsonData = null;
    try {
     
      jsonData = json.stringify(document);
    
    } catch(e) {
      
      throw new WiltException('postDocument() cannot stringify document body , use postDocumentString');
    }
    
    /* Perform the POST */
    post(url,
         jsonData,
         headers);
    
    
  }
  
  /**
   * POST's to the specified  document where the document is supplied as 
   * a JSON string. Must be used if '_id' and or '_rev' are needed.
   */
  void postDocumentString(String document,
                          {String path:null}){
    
    
    if( document == null ) {
      
      throw new WiltException('postDocumentString() expects a document body.');
    }
    
    String url = "";
    if ( path != null ) url = "$url/$path";
    
    /* Set the content type for a post */
    Map headers = new Map<String,String>();
    headers["Content-Type"] = "application/json";
    
    /* Perform the POST */
    post(url,
        document,
        headers);
    
   
    
  }
  
  /**
   * Copies the source document to the destination document with an optional revision
   * NOTE this method uses the CouchDB COPY method which is not standard HTTP.
   */
  void copyDocument( String sourceId,
                     String destinationId,
                     [String rev=null]) {
    
    if( sourceId == null ) {
      
      throw new WiltException('copyDocument () expects a source id.');
    }
    
    if( destinationId == null ) {
      
      throw new WiltException('copyDocument () expects a destination id.');
    }
    
    
    String url = sourceId;
    url = _conditionUrl(url);
    
    /* Create the special COPY header */
    Map headers = new Map<String,String>();
    String destination = destinationId;
    if ( rev != null ) destination = "$destinationId?rev=$rev";
    headers['Destination'] = destination;
    
    /* Send the request */
    _httpRequest('COPY', 
                 url,
                 headers:headers);
    
    
  }
  
  /**
   * Multi document functions
   */
  
  /**
   * Get all documents.
   * The parameters should be self explanatory and are addative.
   * Refer to the CouchDb documentation for further explanation.
   */
  void getAllDocs({bool includeDocs:false,
                   int limit:null,
                   String startKey:null,
                   String endKey:null,
                   List<String> keys:null,
                   bool descending:false}) {
    
    
    /* Validate the parameters */
    if ( (limit != null) && (limit < 0 ) ) {
      
      throw new WiltException('getAllDocs() must have a positive limit');
      
    }
      
    String url = ALLDOCS;
    
    /* Check the parameters and build the URL as needed */
    if ( includeDocs ) {
      
      url = _setURLParameter(url, 
                            'include_docs', 
                            "true");
      
    }
    
    if ( limit != null ) {
      
      url = _setURLParameter(url, 
                             'limit', 
                             limit.toString());
      
    }
    
    if ( startKey != null ) {
      
      String jsonStartkey = '"$startKey"';
      url = _setURLParameter(url,
                             'startkey', 
                             jsonStartkey);
      
    }
    
    if ( endKey != null ) {
      
      String jsonEndkey = '"$endKey"';
      url = _setURLParameter(url,
                             'endkey', 
                             jsonEndkey);
      
    }
    
    if ( descending  ) {
      
      url = _setURLParameter(url, 
                             'descending', 
                             descending.toString());
      
    }
    
    if ( keys != null ) {
     
      String keyString = json.stringify(keys);
      url = _setURLParameter(url, 
                             'keys', 
                             keyString);
    } 
      
    /* Action the request */
    get(url);
    
  }
  
  /**
   * Bulk insert
   * Bulk inserts a list of documents
   */
  void bulk(List< jsonobject.JsonObject> docs,
            [ bool allOrNothing = false]) {
    
    
    /* Validate the parameters */
    if ( docs == null ) {
      
      throw new WiltException('bulk() must have a document list.');
      
    }
    
    String url = BULKDOCS;
    
    if ( allOrNothing ) {
      
      url = _setURLParameter(url,
                             'all_or_nothing', 
                             allOrNothing.toString());
    }
    
    /* Create the bulk insertion data structure */
    Map documentMap = new Map<String,List>();
    documentMap["docs"] = docs;
    String docString = null;
    try{
     
      docString = json.stringify(documentMap);
    
    } catch(e) {
      
      throw new WiltException('bulk() cannot stringify document list, use bulkString.');
      
    }
    
    /* Must set the content type for a post */
    Map headers = new Map<String,String>();
    headers["Content-Type"] = "application/json";
    
    /* Action the request */
    post(url,
         docString,
         headers);
    
  }
  
  /**
   * Bulk insert JSON string version.
   * Must be used if '_id' and or '_rev' are needed in ANY of the documents
   */
  void bulkString( String docs,
            [ bool allOrNothing = false]) {
    
    
    /* Validate the parameters */
    if ( docs == null ) {
      
      throw new WiltException('bulkString() must have a document string.');
      
    }
    
    String url = BULKDOCS;
    
    if ( allOrNothing ) {
      
      url = _setURLParameter(url, 
                             'all_or_nothing', 
                              allOrNothing.toString());
    }
    
    /* Must set the content type for a post */
    Map headers = new Map<String,String>();
    headers["Content-Type"] = "application/json";
    
    /* Action the request */
    post(url,
         docs,
         headers);
    
  }
  
  /**
   *  Database functions 
   */
  
  /**
   * Creates a database with the specified name.
   */
  void createDatabase(String name) {
    
    if( (name == null )) {
      
      throw new WiltException('createDatabase() expects a database name.');
    }
   
    /* The first char of the URL should be a slash. */
    String url = name;
    if( !url.startsWith('/') ) {
     
      url = "/$url";
      
    } 
    
    /* Perform the create */
    _httpRequest('PUT', 
                 url);
    
  }
  
  /**
   * Deletes the specified database
   */
  void deleteDatabase(String name) {
  
    if( name == null )  {
    
      throw new WiltException('deleteDatabase() expects a database name.');
    }
    
    /* The first char of the URL should be a slash. */
    String url = name;
    if( !url.startsWith('/') ) {
     
      url = "/$url";
      
    } 
    
    /* Null the current database if we have deleted it */
    if ( name == db )
      db = null;
    
    /* Perform the delete */
    _httpRequest('DELETE', 
                 url);
    
  }
  
  /**
   *  Informational functions. 
   *  These are non database specific functions.
   */
  
  /**
   * Get current session information from CouchDB
   */
  void getSession() {
    
    String url = SESSION;
                            
    _httpRequest('GET', 
                  url);
    
  }
  
  /**
   * Get current stats from couchdb
   */
  void getStats() {
    
    String url = STATS;
    
    _httpRequest('GET', 
                 url);
    
  }
  
  /**
   * Get all the databases from couchdb
   */
  void getAllDbs() {
    
    String url = ALLDBS;
    
    _httpRequest('GET', 
                 url);
    
  }
  
  /**
   * Authentication
   */
  
  /* Updates the login credentials in Wilt that will be used for all further
   * requests to CouchDB. Both user name and password must be set, even if one
   * or the other is '' i.e empty. After logging in all communication with CouchDB
   * is made using the selected auithentication method.
   */
  void login(String user, 
             String password) {
    
    
   if ( (user == null ) || (password == null) ) {
     
     throw new WiltException('Login() expects a non null user name and password');
   }
     
    _user = user;
    _password = password;
    authenticationType = AUTH_BASIC;
    
  }
  
  /**
   * Utility functions
   */
  
  /**
   * Ask CouchDB to generate IDs.
   * 
   */
  void generateIds([int amount=10]) {
    
    if( amount < 1 ) {
      
      throw new WiltException('generateIds() expects a positive amount.');
    }
    
    String url = UUIDS;
    
    url = _setURLParameter(url, 
                           'count', 
                           amount.toString());
    
    /* Get the uuids */
    _httpRequest('GET', 
                  url);
    
  }
  
  
}
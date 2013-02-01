# 

Contents

1.  [**1 **Introduction][1]
2.  [**2 **Components][2]
    1.  [**2.1 **Ancho IE Addon][3]
        1.  [**2.1.1 **AnchoRuntime][4]
        2.  [**2.1.2 **AnchoAddon][5]
    2.  [**2.2 **Ancho Background Server][6]
        1.  [**2.2.1 **AnchoAddonService][7]
        2.  [**2.2.2 **AnchoAddonBackground][8]
        3.  [**2.2.3 **AnchoBackgroundAPI][9]
        4.  [**2.2.4 **BackgroundWindow][10]
        5.  [**2.2.5 **LogWindow][11]
    3.  [**2.3 **Ancho Commons][12]
    4.  [**2.4 **Ancho Components UML Diagram][13]
3.  [**3 **Chrome APIs Implementation][14]
    1.  [**3.1 **api.js][15]
4.  [**4 **Extension Startup Procedure][16]
5.  [**5 **Testing Strategy][17]
    1.  [**5.1 **Temporary installation procedure][18]

## Introduction  


Ancho for IE consists of two components -* *singleton* background server *and* IE add-on.   
*

The IE extension manages all of the Ancho add-ons (written in javascript and using Chrome API). Content scripts are executed in its runtime.

The background server on the other hand executes background scripts for the initialized Ancho add-ons.

The javascript environment is injected by special *addonAPI* object which serves as communication point between javascript code and the binaries.   


Chrome APIs are implemented in javascript and function implementations which need to work with browser use the *addonAPI* object.  


## Components

All presented classes are declared as COM objects with single thread access.  


### Ancho IE Addon

Project *ancho*. Actual IE add-on - stores all Ancho add-ons.

According to registry entries it creates *AnchoAddon* instances - each requesting background API (contained in the *AnchoAddonBackground* instance) from background server's *AnchoAddonService*.   


Each *AnchoAddon* uses two Magpie instances for processing content and background scripts. Instance executing content scripts resides in *AnchoAddon* object and instance for background scripts resides in *AnchoBackgroundAPI* (contained in *AnchoAddonBackground*).  


#### AnchoRuntime

This object serves as connection point between IE and rest of the IE extension (implements *SetSiteIml()* method). It holds all created instances of AnchoAddon class.   


*   **InitAddons(...)** - Queries *IWebBrowser2* and *AnchoAddonService*. Then it searches registry for Ancho add-ons and initializes all Ancho add-on instances.  
    
*   **DestroyAddons(...)** - It calls *Shutdown()* method for all Ancho add-ons and releases *IWebBrowser2* and *AnchoAddonService*

#### AnchoAddon

This class wraps actual javascript written Ancho add-on (using chrome APIs). It references AnchoAddonBackground where background scripts run. It also creates Magpie instance, where content scripts are executed.  


*   **Init(...)** - Advises the *WebBrowserEvents2*. Asks for *AnchoAddonBackground* object by calling *AnchoAddonService's* *GetExtension()* method.   
    Initializes Magpie instance, which will be used for content script execution.   
    Obtains instance ID from *AnchoAddonBackground *by calling its* AdviseInstance*() method. Also obtains *contentAPI* from *AnchoAddonBackground.*
*   **Shutdown(...)** - Releases all acquired resources (*AnchoAddonBackground*, *AnchoAddonService, **WebBrowserEvents2, *contentAPI).**




*   Event sinks  
    
*   **BrowserNavigateCompleteEvent** - If new page is loaded and contentAPI is available the Magpie instance is reinitialized and contentAPI is added under name chrome. In the end Ancho add-on content scripts are executed.  
    

  
* * *

### Ancho Background Server

Project *AnchoBgSrv*. Application which provides background API for add-ons. Only one instance of the application can be running (singleton).   


#### AnchoAddonService

*   **GetExtension(...)** - If extension of specified name doesn't exist new *AnchoAddonBackground* object wil be created, initialized and returned.  
    

#### AnchoAddonBackground

*   **IAnchoBackground**
*   **GetContentAPI(...) **- passes this request to *AnchoBackgroundAPI*.  
    
*   **GetManifest(...) **  
    
*   **AdviseInstance(...)** - returns new instance ID to caller. This ID is then used to get access to content API.  
    
*   **UnadviseInstance(...)** - releases *contentAPI* for instance with specified ID.  
    

*   **IAnchoBackgroundConsole** - see *LogWindow*. Implementations of logging methods pass their arguments to *backgroundAPI's* log window.  
    

  


#### AnchoBackgroundAPI

This class implements methods which wrap IE interface to make javascript implementation of Chrome APIs easier and cleaner.  




*   **Init(...)** - Initializes Magpie instance, which will be used for script execution (not content scripts).   
    Processes Ancho add-on manifest file and adds it to the global module as "exports.manifest" then adds itself (*AnchoBackgroundAPI* instance) to Magpie main module under the name "addonAPI", which will be used from javascript to access Ancho binary interface.   
    At the end executes api.js script, which finishes the initialization of APIs.  
    
*   **GetContentAPI(...)** - Requests exports (javascript object) from Magpie instance's MainModule.   
    Calls getContentAPI() function from exports (passing *AnchoAddon* instance ID to callee) and returns result of the operation.
*   **ReleaseContentAPI(...)** - Same as above but calls releaseContentAPI() - which releases API for *AnchoAddon* instance with ID passed as parameter.  
    

  


*   IAnchoBackgroundAPI: Interface inherited from IDispatch - it is passed to Magpie as a module extension.  
    
*   **id(...)**
*   **guid(...)**
*   **startBackgroundWindow(...)** - creates new BackgroundWindow, which is initialized by main module "chrome" object, together with URL of the background page.
*   **addEventObject(...)** - each chrome API instance (for each content script, background script, etc.) needs its separate instance of each event, so listeners will be released when API instance is released. This method register new event obejct - so each event can be invoked in all API instances at once.  
    
*   **removeEventObject(...)** - removes event object - called when chrome API is released.  
    
*   **invokeEventObject(...)** - this fires specified event object in all chrome API instances.  
    
*   **invokeExternalEventObject(...)** - this invokes event objects in different ancho addon.  
    
*   **callFunction(...)** - by this method we solve the 'different array constructor' issue. So instead of calling 'apply' method in JS we use this call.  
    

*   Log sinks - these methods are invoked by corresponding Magpie events. All these methods are only wrappers which pass arguments to LogWindow's corresponding methods.   
    
*   **OnLog(...)**
*   **OnDebug(...)**
*   **OnInfo(...)**
*   **OnWarn(...)**
*   **OnError(...)**

#### BackgroundWindow

This class serves as container for Ancho add-on's background page. It's implemented as hidden window.  


It's creation is invoked by *startBackgroundWindow()* method (*IAnchoBackgroundAPI*).

#### LogWindow

This class implements logging interface. It creates window where all log texts are shown.  


*   **IAnchoBackgroundConsole**
*   **log(...)**
*   **debug(...)**
*   **info(...)**
*   **warn(...)**
*   **error(...)**

  
* * *

### Ancho Commons

Project *anchocommons* contains string definitions shared between Ancho Background Server and Ancho. It is linked to both main components as static library.

  


* * *

### Ancho Components UML Diagram

[![][19]][20]

  
  


  
* * *

* * *

  


## Chrome APIs Implementation

[Chrome APIs][20]  


### api.js

Executed by *AnchoBackgroundAPI* at the end of the initialization method. Declares addon *manifest* variable and fill *exports.chrome* by loading all the scripts implementing the chrome APIs.

Instances of *contentAPI* are stored in declared array *contentInstances*. This array is manipulated by calling functions *exports.getContentAPI(instanceID)* and *exports.releaseContentAPI(instanceID)* - these functions are called by *AnchoBackgroundAPI*.

Also processes addon's manifest and if needed it starts background window containing addon's background page.  


* * *

* * *

  


## Extension Startup Procedure

[![][21]][22]

  
* * *

* * *

## Testing Strategy

  


Unit tests for chrome APIs are implemented in form of an Ancho addon (*test-suite-extension*).

For interface testing we use [Jasmine][22] framework, which is included as a part of the test addon.

Internal structure of the test extension:

*   **test-suite-extension/**
*   **spec/** - directory for API specification tests  
    
*   chromeEvents.js - unit test for chrome.events API  
    

*   **vendor/** - directory for 3rd party tool  
    
*   **jasmine/** - unit test framework  
    
*   [require.js][23]  
    

*   Background.html - background page - initialization and unit test execution  
    
*   ConsoleReporter.js - jasmine reporter, which can print into the console  
    
*   content.js - content script  
    
*   manifest.json - manifest describing extension  
    

  


Interface specifications are implemented as **require.js** modules (using *define*). And Jasmine runner is executed in the callback for the *require* call (after successful loading of all spec modules).

### Temporary installation procedure

For *test-suite-extension* exists reg file. Modify it - so path leads to your directory with *test-suite-extension*. Apply the reg file - extension should now load in IE (Ancho must be already installed in the browser) and print outputs to debug console.  


  


 [1]: #TOC-Introduction
 [2]: #TOC-Components
 [3]: #TOC-Ancho-IE-Addon
 [4]: #TOC-AnchoRuntime
 [5]: #TOC-AnchoAddon
 [6]: #TOC-Ancho-Background-Server
 [7]: #TOC-AnchoAddonService
 [8]: #TOC-AnchoAddonBackground
 [9]: #TOC-AnchoBackgroundAPI
 [10]: #TOC-BackgroundWindow
 [11]: #TOC-LogWindow
 [12]: #TOC-Ancho-Commons
 [13]: #TOC-Ancho-Components-UML-Diagram
 [14]: #TOC-Chrome-APIs-Implementation
 [15]: #TOC-api.js
 [16]: #TOC-Extension-Startup-Procedure
 [17]: #TOC-Testing-Strategy
 [18]: #TOC-Temporary-installation-procedure
 [19]: images/Ancho-IE.png
 [20]: http://developer.chrome.com/extensions/api_index.html
 [21]: images/aji-bootup-flowchart.png
 [22]: http://pivotal.github.com/jasmine/
 [23]: http://requirejs.org/
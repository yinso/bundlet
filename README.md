# Bundlet - a simple client-side Javascript bundler.

`Bundlet` is a simple client-side Javascript bundler. It is designed to work with external scripts, such as scripts from CDN or 3rd-party service scripts.

## Install

    npm install -g bundlet
    
## Usage 

In your package.json

    browser: { // this is the same browser field used by browserify
      jquery: false
      ....v
    }
    
    bundlet: {
      shim: {
        jquery: {
          external: 'window.$', // external is a direct text substitution. 
          depends: []
        }, 
      }
    }


In your HTML template

    <script src="jquery.js"></script><!-- make sure external scripts are included ahead -->
    ... 
    <script src="/main.js"></script>

Your modules: 

    // foo.js
    var jquery = require('jquery');
    var Bar = require('./bar');
    var Baz = require('./baz');
    ...
    
    // bar.js
    var jquery = require('jquery');
    var Baz = require('./baz');
    ... 
    
    // baz.js
    ... 


Compile from command line. 

    $ bundlet ./foo.js > ./public/js/foo.js

`./public/js/foo.js` now looks like

    // module: jquery
    var _Module_jquery = window.$;
    // module: ./baz.js
    var _Module___baz_js = (function () {
       ... 
    })();
    // module: ./bar.js
    var _Module___bar_js = (function() {
      var jquery = _Module_jquery;
      var Baz = _Module_baz_js;
      ... 
    })();
    // module: ./foo.js
    var _Module___foo_js = (function () {
      var jquery = _Module_jquery;
      var Bar = _Module___bar_js;
      var Baz = _Module___baz_js;
      ...
    })();

## Package.json `browser` field

`bundlet` utilizes [`browser` field](https://gist.github.com/defunctzombie/4339901) similar to `browserify`. Use it to provide alternate script or `false` to ignore script in the case when the script will be supplied externally.

## Package.json `bundlet` field

Use `bundlet` field to drive the rest of the `bundlet` behaviors. Currently the only field defined within `bundlet` is `shims`. 

### `bundlet.shims`

`shims` is a key/value pair object, where the key denotes the name of a module. 

The value is another object that have the following values: 

- `external` - supply the definition of the external script. For example - `external: 'window.$'` will be used for defining the object. Use `external` in pair with `false` in `browser` field.
- `depends` - an array of the dependant scripts. This is used to drive external script's dependency when they do not utilize `require`. 
- `exports` - For external scripts that do not utilize `module.exports` - use this to return something else. 

`depends` and `exports` are used with scripts that you want to bundle, since you would handle them manually when they are external scripts.

The following is an example: 

    browser: {
      jquery: false, // loading from CDN
      bootstrap: './public/js/bootstrap.js', 
      bootstrap.tagsinput: './public/js/bootstrap.tagsinput.js'
    }
    
    bundlet: {
      shims: {
        jquery: {
          external: 'window.$';
        }, 
        bootstrap: {
          depends: ['jquery'], 
        },
        bootstrap.tagsinput: {
          depends: ['jquery', 'bootstrap']
        } 
      }
    }

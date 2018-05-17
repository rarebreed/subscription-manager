const path = require('path')
const copy = require("copy-webpack-plugin")
const fs = require("fs");
const webpack = require("webpack")
const ExtractTextPlugin = require('extract-text-webpack-plugin')
const po2json = require("po2json")
const glob = require("glob")

/* These can be overridden, typically from the Makefile.am */
const srcdir = (process.env.SRCDIR || __dirname) + path.sep + "src";
const builddir = (process.env.SRCDIR || __dirname);
const distdir = builddir + path.sep + "dist";
const section = process.env.ONLYDIR || null;
const nodedir = path.resolve((process.env.SRCDIR || __dirname), "node_modules");
let distPath = path.resolve(__dirname, 'dist')
console.log(`distdir=${distdir}, distPath=${distPath}`)

/* A standard nodejs and webpack pattern */
var production = process.env.NODE_ENV === 'production';
const TESTING = process.env.NODE_ENV === "testing";
console.log(`NODE_ENV=${process.env.NODE_ENV}`)

class Po2JSONPlugin {
    apply(compiler) {
        compiler.plugin('emit', function(compilation, callback) {
            const files = glob.sync('../po/*.po')
            files.forEach(function(file) {
                const dataFileName = `po.${/([^/]*).po$/.exec(file)[1]}.js`
                const data = `cockpit.locale(${JSON.stringify(po2json.parseFileSync(file))});`
                compilation.assets[dataFileName] = {
                    source: function() {
                        return data
                    },
                    size: function() {
                        return data.length
                    },
                }
            })
            callback()
        })
    }
}

let plugins = [
    // new CleanWebpackPlugin(["dist"]),
    new webpack.ProvidePlugin({
        '$': 'jquery',
        'jQuery': 'jquery',
    }),
    new ExtractTextPlugin("bulma.css"),
    new Po2JSONPlugin()
]

if (!production) {
    console.log("Copying over files for testing")
    plugins.unshift(new copy([
        {
            from: './src/test/manifest.json',
            to: 'manifest.json'
        },
        {
            from: './src/test/SpecRunner.html',
            to: 'SpecRunner.html'
        },
        {
            from: './node_modules/jasmine-core/lib/jasmine-core/jasmine.css',
            to: 'jasmine/jasmine.css'
        },
        {
            from: './node_modules/jasmine-core/lib/jasmine-core/jasmine.js',
            to: 'jasmine/jasmine.js',
        },
        {
            from: './node_modules/jasmine-core/lib/jasmine-core/jasmine-html.js',
            to: 'jasmine/jasmine-html.js'
        },
        {
            from: './node_modules/jasmine-core/lib/jasmine-core/boot.js',
            to: 'jasmine/boot.js'
        },
        {
            from: './node_modules/jasmine-core/images/jasmine_favicon.png',
            to: 'jasmine/jasmine_favicon.png'
        }
    ]));
}

/* Only minimize when in production mode */
if (production) {
    /* Why are we doing this?  Webpack 2+ already does tree shaking
    plugins.unshift(new webpack.optimize.UglifyJsPlugin({
        beautify: true,
        compress: {
            warnings: false
        },
    }));
    */

    /* Rename output files when minimizing */
    output.filename = "[name].min.js";

    plugins.unshift(new CompressionPlugin({
        asset: "[path].gz[query]",
        test: /\.(js|html)$/,
        minRatio: 0.9,
        deleteOriginalAssets: true
    }));
}

module.exports = {
    entry:  "./src/test/spec/dbus/dbus.test.ts",
    devtool: "inline-source-map",
    output: {
        filename: "bundle.js",
        path: distPath,
        //publicPath: "dist/"
    },
    resolve: {
        // Add '.ts' and '.tsx' as a resolvable extension.
        extensions: [".jsx", ".ts", ".tsx", ".js"],
    },
    module: {
        rules: [
            /* We will let the ts-loader (which calls the tsc compiler under the hood) to do es6 and jsx conversion for us
               We will also use the tslint module do the linting.
             */
            { 
                test: /\.tsx?$/, 
                use: "ts-loader" 
            },
            { 
                exclude: /node_modules/,
                test: /\.css$/, 
                use: ExtractTextPlugin.extract({fallback: "style-loader", use: "css-loader"})
            },
            { 
                // Look for any image files, and if they are more than 20k, load in separate dir 
                test: /\.({jpe?g}|png|gif|svg)$/, 
                use: [
                  {
                      loader: 'url-loader',
                      options: { limit: 20000 }
                  },
                  'image-webpack-loader'
                ]
            }
        ]
    },
    plugins: plugins,
    externals: {
        cockpit: "cockpit",
        jasmine: "jasmine",
        fs: {
            commonjs: 'fs'
        }
    }
}
// Install dependencies:
//
//     npm install --no-save @rsbuild/core @rsbuild/plugin-react @rsbuild/plugin-svgr @rsbuild/plugin-sass @rsdoctor/rspack-plugin
//
// Build with:
//
//     rsbuild build
//
// Develop with:
//
//     rsbuild
//
// Troubleshoot with:
//
//     RSDOCTOR=true rsbuild build

import path from 'path';
import fs from 'fs';
import { defineConfig } from '@rsbuild/core';
import { pluginReact } from '@rsbuild/plugin-react';
import { pluginSvgr } from '@rsbuild/plugin-svgr';
import { pluginSass } from '@rsbuild/plugin-sass';
import { loadEnv } from '@rsbuild/core';

// Load environment variables
// https://rsbuild.dev/api/javascript-api/core#loadenv
const currentDir = process.cwd();
const parsedEnv = loadEnv({ mode: 'production' }).parsed;
const parsedEnvDev = loadEnv({ mode: 'development' }).parsed;
const appName = parsedEnv.APP_ID || path.basename(currentDir).replace('frontend-app-', '');
const publicPath = parsedEnv.PUBLIC_PATH || '/' + appName + '/';
const dev = parsedEnv.NODE_ENV === 'development';
const prod = !dev;
const isArm64 = (process.arch === 'arm64');
const srcDir = path.resolve(currentDir, 'src');
parsedEnv.APP_ID = appName;
parsedEnv.PUBLIC_PATH = publicPath;
parsedEnv.MFE_CONFIG_API_URL = prod ? '/api/mfe_config/v1' : 'http://local.openedx.io:8000/api/mfe_config/v1';

// Load env.config.(js|jsx)
var envConfigPath = '';
try {
    await import('@openedx/frontend-plugin-framework');
    if (fs.existsSync(path.resolve(currentDir, './env.config.jsx'))) {
        envConfigPath = path.resolve(currentDir, './env.config.jsx');
    } else if (fs.existsSync(path.resolve(currentDir, './env.config.js'))) {
        envConfigPath = path.resolve(currentDir, './env.config.js');
    }
} catch {
    // FPF is not available, we don't try to load env.config.js
}

const config = defineConfig({
    html: {
        template: './public/index.html',
    },
    output: {
        // Flat directory
        // TODO do we want a flat directory?
        // distPath: {
        //     js: '',
        //     css: '',
        // },
        sourceMap: {
            js: prod ? 'source-map' : 'eval',
            css: true,
        }
    },
    performance: {
        // We enable caching everywhere except on amd64, even if it's unnecessary in
        // some places. The negative impact on performance should be minor.
        // The reason we disable it on arm64 is that build is failing on this platform
        // https://github.com/web-infra-dev/rspack/issues/10118
        buildCache: isArm64 ? false : true,
    },
    server: {
        base: publicPath,
        // Redirect all get requests to index.html
        // https://rsbuild.dev/config/server/history-api-fallback
        historyApiFallback: true,
        port: parseInt(parsedEnvDev.PORT),
    },
    source: {
        define: {
            // This is explicitly recommended against, but this is how MFEs are built
            // https://rsbuild.dev/guide/advanced/env-vars#processenv-replacement
            'process.env': JSON.stringify(parsedEnv),
        },
        transformImport: [
            // https://rsbuild.dev/config/source/transform-import#import-lodash-on-demand
            {
                libraryName: 'lodash',
                customName: 'lodash/{' + '{ member }' + '}',
            },
            {
                libraryName: '@fortawesome/free-brands-svg-icons',
                customName: '@fortawesome/free-brands-svg-icons/{' + '{ member }' + '}',
                transformToDefaultImport: false,
            },
            {
                libraryName: '@fortawesome/free-regular-svg-icons',
                customName: '@fortawesome/free-regular-svg-icons/{' + '{ member }' + '}',
                transformToDefaultImport: false,
            },
            {
                libraryName: '@fortawesome/free-solid-svg-icons',
                customName: '@fortawesome/free-solid-svg-icons/{' + '{ member }' + '}',
                transformToDefaultImport: false,
            },
        ],
    },
    plugins: [
        // https://rsbuild.dev/plugins/list/plugin-react
        pluginReact(),
        // https://rsbuild.dev/plugins/list/plugin-svgr#mixedimport
        pluginSvgr({
            mixedImport: true,
            svgrOptions: {
                exportType: 'named',
            },
        }),
        // https://rsbuild.dev/plugins/list/plugin-sass
        pluginSass({
            sassLoaderOptions: {
                sassOptions: {
                    silenceDeprecations: ['abs-percent', 'color-functions', 'import', 'mixed-decls', 'global-builtin', 'legacy-js-api'],
                },
            },
        }),
    ],
    resolve: {
        // Match the historical webpack-based MFEs behavior as closely as possible:
        // - allow absolute imports from `src/` (webpack `resolve.modules: ['src', 'node_modules']`)
        // - support both `@src/...` and `src/...` prefixes (some repos used one or the other)
        modules: [srcDir, 'node_modules'],
        alias: {
            'env.config': envConfigPath || false,
            '@src': srcDir,
            'src': srcDir,
        }
    },
    tools: {
        rspack: (
            rspackConfig: any,
            { addRules }: { addRules: (rules: any) => void },
        ) => {
            // Webpack historically allowed `import x from "*.css"` and then using `x.toString()`
            // (via css-loader's JS exports). Rspack's native CSS handling is side-effect only
            // for non-module CSS, so TinyMCE skin imports like:
            //   import contentUiCss from 'tinymce/skins/ui/oxide/content.css'
            // would otherwise have no default export.
            //
            // We load these specific CSS files as source strings so the existing code works
            // without modifications.
            addRules({
                test: /\.css$/,
                include: /[\\/]node_modules[\\/]tinymce[\\/]skins[\\/]/,
                type: 'asset/source',
            });

            return rspackConfig;
        },
    },
});

///////////////////////
// MFE-specific changes
///////////////////////

// This is horrible but we don't have a choice
if (appName == 'authoring') {
    config.resolve!.alias!['CourseAuthoring'] = path.resolve(currentDir, 'src/');
}

export default config;

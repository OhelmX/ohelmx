

function addPlugins(config, slot_name, plugins) {
  if (slot_name in config.pluginSlots === false) {
    config.pluginSlots[slot_name] = {
      keepDefault: true,
      plugins: []
    };
  }

  config.pluginSlots[slot_name].plugins.push(...plugins);
}

async function setConfig () {
  let config = {
    pluginSlots: {}
  };

  try {
    /* We can't assume FPF exists, as it's not declared as a dependency in all
     * MFEs, so we import it dynamically. In addition, for dynamic imports to
     * work with Webpack all of the code that actually uses the imported module
     * needs to be inside the `try{}` block.
     */
    const { DIRECT_PLUGIN, PLUGIN_OPERATIONS } = await import('@openedx/frontend-plugin-framework');
    if (process.env.APP_ID == 'admin-console') {
    }
    if (process.env.APP_ID == 'authn') {
    }
    if (process.env.APP_ID == 'authoring') {
    }
    if (process.env.APP_ID == 'account') {
    }
    if (process.env.APP_ID == 'communications') {
    }
    if (process.env.APP_ID == 'discussions') {
    }
    if (process.env.APP_ID == 'gradebook') {
    }
    if (process.env.APP_ID == 'learner-dashboard') {
    }
    if (process.env.APP_ID == 'learning') {
    }
    if (process.env.APP_ID == 'ora-grading') {
    }
    if (process.env.APP_ID == 'profile') {
    }
  } catch (err) { console.error("env.config.jsx failed to apply: ", err);}

  return config;
}

export default setConfig;
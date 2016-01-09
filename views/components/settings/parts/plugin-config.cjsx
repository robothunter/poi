Promise = require 'bluebird'
path = require 'path-extra'
glob = require 'glob'
__ = i18n.setting.__.bind(i18n.setting)
__n = i18n.setting.__n.bind(i18n.setting)
fs = require 'fs-extra'
npm = require 'npm'
semver = require 'semver'
{$, $$, _, React, ReactBootstrap, FontAwesome, ROOT, PluginManager} = window
{Grid, Col, Row, Input, Alert, Button, ButtonGroup, Label, Collapse, Well, OverlayTrigger, Tooltip} = ReactBootstrap
{config} = window
shell = require 'shell'
{dialog} = remote.require 'electron'
Divider = require './divider'

PluginConfig = React.createClass
  getInitialState: ->
    checkingUpdate: false
    hasUpdates: false
    npmWorkding: false
    installingAll: false
    installingPluginNames: []
    config: {}
    mirrors: {}
    plugins: []
    uninstalledPluginSettings: []
    updatingAll: false
    reloading: false
    advanced: false
    manuallyInstallPackage: ''
  isUpdateAvailable: false
  checkCount: 0
  emitReload: ->
    PluginManager.emitReload()
  readPlugins: ->
    initState = @getInitialState()
    initState.reloading = true
    @setState initState
    PluginManager.getMirrors().then (mirrors) =>
      PluginManager.getConf().then (config) =>
        PluginManager.readPlugins().then =>
          @updateFromPluginManager {
            mirrors: mirrors
            config: config
            reloading: false
          }
  updateFromPluginManager: (newState) ->
    newState ?= {}
    state = @state
    PluginManager.getInstalledPlugins().then (plugins) =>
      PluginManager.getUninstalledPluginSettings().then (settings) =>
        newState.plugins = plugins
        newState.uninstalledPluginSettings = settings
        for key of newState
          state[key] = newState[key]
        @setState state
  handleClickAuthorLink: (link, e) ->
    shell.openExternal link
    e.preventDefault()
  handleEnableBetaPluginCheck: ->
    PluginManager.selectConfig(null, null, !@state.config.betaCheck).then (config) =>
      @setState
        config: config
  handleEnableProxy: ->
    PluginManager.selectConfig(null, !@state.config.proxy, null).then (config) =>
      @setState
        config: config
  onSelectServer: (state) ->
    PluginManager.selectConfig(state ,null, null).then (config) =>
      @setState
        config: config
  handleAdvancedShow: ->
    advanced = !@state.advanced
    @setState {advanced}
  changeInstalledPackage: (e) ->
    manuallyInstallPackage = e.target.value
    @setState {manuallyInstallPackage}
  handleEnable: (index) ->
    PluginManager.getInstalledPlugins().then (plugins) =>
      plugin = plugins[index]
      switch PluginManager.getStatusOfPlugin plugin
        when PluginManager.DISABLED
          PluginManager.enablePlugin plugin
        when PluginManager.VALID
          PluginManager.disablePlugin plugin
      @updateFromPluginManager()
  handleInstall: (name) ->
    if !@props.disabled
      installingPluginNames = @state.installingPluginNames
      installingPluginNames.push name
      @setState installingPluginNames: installingPluginNames, npmWorkding: true
      PluginManager.installPlugin(name).then =>
        installingPluginNames = @state.installingPluginNames
        index = installingPluginNames.indexOf name
        if index > -1
          installingPluginNames.splice index, 1
          @updateFromPluginManager {
            installingPluginNames: installingPluginNames
            npmWorkding: false
          }
      .catch =>
        @updateFromPluginManager {
          npmWorkding: false
        }
  handleUpdate: (index) ->
    if !@props? || !@props.disabled
      plugins = @state.plugins
      plugins[index].isUpdating = true
      @setState npmWorkding: true
      PluginManager.getInstalledPlugins().then (plugins) =>
        plugin = @state.plugins[index]
        PluginManager.updatePlugin(plugin).then =>
          plugins[index].isUpdating = false
          plugins[index].isOutdated = false
          plugins[index].version = plugins[index].lastestVersion
          @updateFromPluginManager npmWorkding: false
          Promise.resolve()
        .catch =>
          plugins[index].isUpdating = false
          @updateFromPluginManager npmWorkding: false
          Promise.reject()
  handleInstallAll: ->
    @setState installingAll: true
    PluginManager.getUninstalledPluginSettings().then (settings) =>
      Promise.coroutine( =>
        err = false
        for name, value of settings
          yield @handleInstall(name).then =>
            console.log 'barfoo!'
          .catch =>
            console.log 'not barfoo!'
            err = true
        if !err
          @setState
            hasUpdates: false
            installingAll: false
        else
          @setState
            installingAll: false
      )()
  handleUpdateAll: ->
    if !@props.disabled
      @setState updatingAll: true
      Promise.coroutine( =>
        err = false
        for plugin, index in @state.plugins
          if @state.plugins[index].isOutdated
            yield @handleUpdate(index).catch =>
              err = true
        if !err
          @setState
            hasUpdates: false
            updatingAll: false
        else
          @setState
            updatingAll: false
      )()
  handleRemove: (index) ->
    if !@props.disabled
      PluginManager.getInstalledPlugins().then (plugins) =>
        plugin = plugins[index]
        @setState npmWorkding: true
        PluginManager.uninstallPlugin(plugin).then =>
          @updateFromPluginManager npmWorkding: false
  checkUpdate: ->
    @setState checkingUpdate: true
    PluginManager.getOutdatedPlugins().then (plugins) =>
      @updateFromPluginManager {
        hasUpdates: plugins.length isnt 0
        checkingUpdate: false
      }
  onSelectOpenFolder: ->
    shell.openItem path.join PLUGIN_PATH, 'node_modules'
  onSelectOpenSite: (e) ->
    shell.openExternal "https://www.npmjs.com/search?q=poi-plugin"
    e.preventDefault()
  onSelectInstallFromFileComplete: (data, er) ->
  onSelectInstallFromFile: (callback) ->
    @synchronize =>
      filenames = dialog.showOpenDialog
        title: __ 'Select files'
        defaultPath: remote.require('electron').app.getPath('downloads')
        properties: ['openFile', 'multiSelections']
      if filenames
        npm.load npmConfig, (err) =>
          npm.commands.install filenames, (er, data) ->
            callback(data, er)
  onDropInstallFromFile: (callback, e) ->
    e.preventDefault()
    droppedFiles = e.dataTransfer.files
    filenames = []
    for droppedFile in droppedFiles
      filenames.push droppedFile.path
    if filenames
      npm.load npmConfig, (err) =>
        npm.commands.install filenames, (er, data) ->
          callback(data, er)
  handleManuallyInstall: (name, callback) ->
  handleReinstall: (index) ->
  handleReinstallComplete: (data, er) ->
  handleRemoveBroken: (index, callback) ->
  handleRemoveBrokenComplete: (index ,er) ->
  synchronize: (callback) ->
    return if @lock
    @lock = true
    callback()
    @lock = false
  componentDidMount: ->
    PluginManager.getMirrors().then (mirrors) =>
      PluginManager.readPlugins(true)
      PluginManager.getConf().then (config) =>
        @setState checkingUpdate: true
        PluginManager.getOutdatedPlugins(true).then (plugins) =>
          @updateFromPluginManager {
            hasUpdates: plugins.length isnt 0
            checkingUpdate: false
            mirrors: mirrors
            config: config
          }
  render: ->
    <form>
      <Divider text={__ 'Plugins'} />
      <Grid>
        <Col xs={12}>
          <Alert bsStyle='info'>
            {__ 'You must reboot the app for the changes to take effect.'}
          </Alert>
        </Col>
      </Grid>
      <Grid>
        <Col xs={12} style={padding: '10px 15px'}>
          <ButtonGroup bsSize='small' style={width: '100%'}>
            <Button onClick={@checkUpdate}
                    disabled={@state.checkingUpdate}
                    className="control-button"
                    style={width: '25%'}>
              <FontAwesome name='refresh' spin={@state.checkingUpdate} />
              <span> {__ "Check Update"}</span>
            </Button>
            <Button onClick={@handleUpdateAll}
                    disabled={@state.npmWorkding ||
                      !@state.hasUpdates || @state.checkingUpdate}
                    className="control-button"
                    style={width: '25%'}>
              <FontAwesome name={if @state.updatingAll then 'spinner' else 'cloud-download'}
                           pulse={@state.updatingAll}/>
              <span> {__ "Update all"}</span>
            </Button>
            <Button onClick={@handleInstallAll}
                    disabled={@state.npmWorkding}
                    className="control-button"
                    style={width: '25%'}>
              <FontAwesome name={if @state.installingAll then 'spinner' else 'download'}
                           pulse={@state.installingAll}/>
              <span> {__ "Install all"}</span>
            </Button>
            <Button onClick={@handleAdvancedShow}
                    className="control-button"
                    style={width: '25%'}>
              <FontAwesome name="gear" />
              <span> {__ "Advanced"} </span>
              <FontAwesome name="#{if @state.advanced then 'angle-up' else 'angle-down'}" />
            </Button>
          </ButtonGroup>
          <Collapse in={@state.advanced}>
            <div>
              <Well>
                <Row>
                  <Col xs=12>
                    {
                      installButton =
                        <Button bsStyle='primary' onClick={@handleManuallyInstall.bind @, @state.manuallyInstallPackage, @onSelectInstallFromFileComplete}>
                          {__ 'Install'}
                        </Button>
                      <Input type="text"
                             value={@state.manuallyInstallPackage}
                             onChange={@changeInstalledPackage}
                             label={__ 'Install directly from npm'}
                             placeholder={__ 'Input plugin package name...'}
                             bsSize='small'
                             buttonAfter={installButton} />
                    }
                  </Col>
                  <Col xs=12>
                    <label className='control-label' style={width: '100%'}>
                      {__ 'Select npm server'}
                    </label>
                    {
                      index = -1
                      for server of @state.mirrors
                        index++
                        <OverlayTrigger placement='top' key={index} overlay={<Tooltip id="npm-server-#{index}">{@state.mirrors[server].menuname}</Tooltip>}>
                          <Col key={index} xs=6 style={padding: '0px 5px'}>
                            <Input type="radio"
                                   label={@state.mirrors[server].name}
                                   checked={@state.config.mirror.server == @state.mirrors[server].server}
                                   onChange={@onSelectServer.bind @, server} />
                          </Col>
                        </OverlayTrigger>
                    }
                  </Col>
                  <Col xs=12>
                    <label className='control-label' style={width: '100%'}>
                      {__ 'Others'}
                    </label>
                    <div>
                      <Input type="checkbox" label={__ 'Connect to npm server through proxy'}
                             checked={@state.config.proxy}
                             onChange={@handleEnableProxy} />
                    </div>
                    <div>
                      <Input type="checkbox" label={__ 'Developer option: check update of beta version'}
                             checked={@state.config.betaCheck}
                             onChange={@handleEnableBetaPluginCheck} />
                    </div>
                    <ButtonGroup style={width: '100%'}>
                      <Button style={width: '50%'} onClick={@onSelectOpenFolder}>
                        {__ 'Open plugin folder'}
                      </Button>
                      <Button style={width: '50%'} onClick={@onSelectOpenSite}>
                        {__ 'Search for plugins'}
                      </Button>
                    </ButtonGroup>
                  </Col>
                </Row>
              </Well>
            </div>
          </Collapse>
        </Col>
        <Col xs={12} style={paddingBottom: 10}>
          <div className="folder-picker"
               onClick={@onSelectInstallFromFile.bind @, @onSelectInstallFromFileComplete}
               onDrop={@onDropInstallFromFile.bind @, @onSelectInstallFromFileComplete}
               onDragEnter={(e)=> e.preventDefault()}
               onDragOver={(e)=> e.preventDefault()}
               onDragLeave={(e)=> e.preventDefault()}>
            {__ "Drop plugin packages here to install it, or click here to select them"}
          </div>
        </Col>
      {
        for plugin, index in @state.plugins
          <Col key={index} xs={12} style={marginBottom: 8}>
            <Col xs={12} className='div-row'>
              <span style={fontSize: '150%'}>{plugin.displayName} </span>
              <span style={paddingTop: 2}> @<span onClick={@handleClickAuthorLink.bind @, plugin.link}>{plugin.author}</span></span>
              <div style={paddingTop: 2}>
                <Label bsStyle="#{if plugin.lastestVersion.indexOf('beta') == -1 then 'primary' else 'warning'}"
                       className="#{if not plugin.isOutdated then 'hidden'}">
                  <FontAwesome name='cloud-upload' />
                  Version {plugin.lastestVersion}
                </Label>
              </div>
              <div style={paddingTop: 2, marginLeft: 'auto'}>Version {plugin.version || '1.0.0'}</div>
            </Col>
            <Col xs={12} style={marginTop: 4}>
              <Col xs={5}>{plugin.description}</Col>
              <Col xs={7} style={padding: 0}>
                <div style={marginLeft: 'auto'}>
                  <ButtonGroup bsSize='small' style={width: '100%'}>
                    <Button bsStyle='info'
                            disabled={PluginManager.getStatusOfPlugin(plugin) == PluginManager.NEEDUPDATE}
                            onClick={@handleEnable.bind @, index}
                            style={width: "33%"}
                            className="plugin-control-button">
                      <FontAwesome name={
                                     switch PluginManager.getStatusOfPlugin plugin
                                       when PluginManager.VALID
                                         "pause"
                                       when PluginManager.DISABLED
                                         "play"
                                       when PluginManager.NEEDUPDATE
                                         "ban"
                                       when PluginManager.BROKEN
                                         "close"
                                   }/>
                      {
                        switch PluginManager.getStatusOfPlugin plugin
                          when PluginManager.VALID
                            __ "Disable"
                          when PluginManager.DISABLED
                            __ "Enable"
                          when PluginManager.NEEDUPDATE
                            __ "Outdated"
                          when PluginManager.BROKEN
                            __ "Error"
                      }
                    </Button>
                    <Button bsStyle='primary'
                            disabled={not plugin.isOutdated || plugin.isUpdating || @state.npmWorkding || @state.checkingUpdate}
                            onClick={@handleUpdate.bind @, index}
                            style={width: "33%"}
                            className="plugin-control-button">
                      <FontAwesome name={
                                     if plugin.isUpdating
                                       "spinner"
                                     else if plugin.isOutdated
                                       "cloud-download"
                                     else
                                       "check"
                                   }
                                   pulse={plugin.isUpdating}/>
                      {
                        if plugin.isUpdating
                           __ "Updating"
                        else if plugin.isOutdated
                           __ "Update"
                        else
                           __ "Latest"
                      }
                    </Button>
                    <Button bsStyle='danger'
                            onClick={@handleRemove.bind @, index}
                            disabled={not plugin.isInstalled}
                            style={width: "33%"}
                            className="plugin-control-button">
                      <FontAwesome name={if plugin.isInstalled then 'trash' else 'trash-o'} />
                      {
                        if plugin.isUninstalling
                          __ "Removing"
                        else if plugin.isInstalled
                          __ "Remove"
                        else
                          __ "Removed"
                      }
                    </Button>
                  </ButtonGroup>
                </div>
              </Col>
            </Col>
          </Col>
      }
      {
        for name, index in Object.keys(@state.uninstalledPluginSettings)
          value = @state.uninstalledPluginSettings[name]
          <Col key={index} xs={12} style={marginBottom: 8}>
            <Col xs={12} className='div-row'>
              <span style={fontSize: '150%'}>
                <FontAwesome name={value.icon} />
                  {value[window.language]}
                </span>
              <span style={paddingTop: 2}> @
                <span onClick={@handleClickAuthorLink.bind @, value.link}>
                  {value.author}
                </span>
              </span>
            </Col>
            <Col xs={12} style={marginTop: 4}>
              <Col xs={8}>{value["des#{window.language}"]}</Col>
              <Col xs={4} style={padding: 0}>
                <div style={marginLeft: 'auto'}>
                  <ButtonGroup bsSize='small' style={width: '100%'}>
                    <Button bsStyle='primary'
                            disabled={@state.npmWorkding}
                            onClick={@handleInstall.bind @, name}
                            style={width: "100%"}
                            className="plugin-control-button">
                      <FontAwesome name={
                                     if name in @state.installingPluginNames
                                       'spinner'
                                     else
                                       'download'
                                   }
                                   pulse={name in @state.installingPluginNames}/>
                      {
                        if name in @state.installingPluginNames
                          __ "Installing"
                        else
                          __ "Install"
                      }
                    </Button>
                  </ButtonGroup>
                </div>
              </Col>
            </Col>
          </Col>
      }
      </Grid>
    </form>

module.exports = PluginConfig

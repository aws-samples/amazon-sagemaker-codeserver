// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import { JupyterFrontEnd, JupyterFrontEndPlugin, ILayoutRestorer } from '@jupyterlab/application';
import { ILauncher } from '@jupyterlab/launcher';
import { PageConfig } from '@jupyterlab/coreutils';
import { LabIcon } from '@jupyterlab/ui-components';
import { IFrame, MainAreaWidget, WidgetTracker } from '@jupyterlab/apputils';

import CODESERVER_ICON from "../style/icons/codeserver.svg"
import OTHERSERVER_ICON from "../style/icons/otherserver.svg"

export const codeserverIcon = new LabIcon({
  name: 'codeserver:icon',
  svgstr: CODESERVER_ICON
});

export const otherserverIcon = new LabIcon({
  name: 'otherserver:icon',
  svgstr: OTHERSERVER_ICON
});

function newServerProxyWidget(id: string, url: string, text: string): MainAreaWidget<IFrame> {
  const content = new IFrame({
    sandbox: ['allow-same-origin', 'allow-scripts', 'allow-popups', 'allow-forms', 'allow-downloads', 'allow-modals'],
  });
  content.title.label = text;
  content.title.closable = true;
  content.url = url;
  content.addClass('jp-ServerProxy');
  content.id = id;
  const widget = new MainAreaWidget({ content });
  widget.addClass('jp-ServerProxy');
  return widget;
}

async function activate(app: JupyterFrontEnd, launcher: ILauncher, restorer: ILayoutRestorer) : Promise<void> {
  const response = await fetch(PageConfig.getBaseUrl() + 'server-proxy/servers-info');
  if (!response.ok) {
    console.log('Could not fetch metadata about registered servers. Make sure jupyter-server-proxy is installed.');
    console.log(response);
    return;
  }
  const { commands, shell } = app;

  const data:IServersInfo = await response.json();
  const namespace = 'sm-server-proxy';
  const tracker = new WidgetTracker<MainAreaWidget<IFrame>>({
    namespace
  });
  const command = namespace + ':' + 'open';

  if (restorer) {
    void restorer.restore(tracker, {
      command: command,
      args: widget => ({
        url: widget.content.url,
        title: widget.content.title.label,
        newBrowserTab: false,
        id: widget.content.id
      }),
      name: widget => widget.content.id
    });
  }

  commands.addCommand(command, {
    label: args => args['title'] as string,
    icon: args => (args['icon_url'] as string).endsWith('codeserver') ? codeserverIcon : otherserverIcon ,
    execute: args => {
      const id = args['id'] as string;
      const title = args['title'] as string;
      const url = args['url'] as string;
      const newBrowserTab = args['newBrowserTab'] as boolean;

      console.warn('Icon URL is set to: ' + args['icon_url']);

      if (newBrowserTab) {
        window.open(url, '_blank');
        return;
      }
      let widget = tracker.find((widget) => { return widget.content.id == id; });
      if(!widget){
        widget = newServerProxyWidget(id, url, title);
      }
      if (!tracker.has(widget)) {
        void tracker.add(widget);
      }
      if (!widget.isAttached) {
        shell.add(widget);
        return widget;
      } else {
        shell.activateById(widget.id);
      }
    }
  });

  for (const server_process of data.server_processes) {
    if (!server_process.launcher_entry.enabled) {
      continue;
    }

    const url = PageConfig.getBaseUrl() + server_process.launcher_entry.path_info;
    const title = server_process.launcher_entry.title;
    const newBrowserTab = server_process.new_browser_tab;
    const id = namespace + ':' + server_process.name;
    const icon_url = server_process.launcher_entry.icon_url;

    const launcher_item : ILauncher.IItemOptions = {
      command: command,
      args: {
        url: url,
        title: title,
        newBrowserTab: newBrowserTab,
        id: id,
        icon_url: icon_url
      },
      category: 'Other'
    };

    launcher.add(launcher_item);
  }
}

const extension: JupyterFrontEndPlugin<void> = {
  id: 'sagemaker-jproxy-launcher-ext',
  autoStart: true,
  requires: [ILauncher, ILayoutRestorer],
  activate: activate
};

export default extension;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

declare module "*.svg" {
    const content: any;
    export default content;
}

interface IServerProcess {
    name: string,
    launcher_entry: ILauncherEntry
}

interface ILauncherEntry {
    enabled: boolean,
    title: string,
    icon_url: string
}

interface IServersInfo {
    server_processes: IServerProcess[]
}

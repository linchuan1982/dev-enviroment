#!/bin/bash

sslocal -c /proxy/shadowsocks.json &
polipo socksParentProxy=localhost:1086


#!/bin/bash

butane --pretty --strict < butane.bu > butane.ign

cat butane.ign | base64 -w0 -
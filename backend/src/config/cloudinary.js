'use strict';

const cloudinary = require('cloudinary').v2;
const { env } = require('./env');

let configured = false;

function configureCloudinary() {
  if (configured) return cloudinary;
  if (env.cloudinaryCloudName && env.cloudinaryApiKey && env.cloudinaryApiSecret) {
    cloudinary.config({
      cloud_name: env.cloudinaryCloudName,
      api_key: env.cloudinaryApiKey,
      api_secret: env.cloudinaryApiSecret,
      secure: true,
    });
    configured = true;
  }
  return cloudinary;
}

function isConfigured() {
  configureCloudinary();
  return configured;
}

module.exports = { cloudinary, configureCloudinary, isConfigured };

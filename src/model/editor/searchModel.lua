local class = require('util.class')

--- @alias itemid integer

--- @class Result
--- @field id itemid
--- @field preview string
--- @field text string

--- @class Search
--- @field input UserInputModel
--- @field searchset { [itemid]: table }
--- @field resultset Result[]
--- @field selection integer

--- @param cfg Config
Search = class.create(function(cfg)
  return {
    input = UserInputModel(cfg, nil, false, 'search'),
  }
end)
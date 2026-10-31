local _, T = ...

-- enUS is the key set: an untranslated key falls through to itself, so a missing
-- locale entry shows English rather than nothing.
T.L = setmetatable({}, {
    __index = function(_, key) return key end,
})

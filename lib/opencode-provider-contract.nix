{
  provider = ''.provider[$p] | type == "object" and .npm == $n and .options.baseURL == $u'';
  models = ''.provider[$p].models | type == "object" and length > 0'';
}

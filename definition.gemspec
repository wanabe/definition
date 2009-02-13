# -*- coding: UTF-8 -*-
Gem::Specification.new do |spec|
  spec.name = "definition"
  spec.version = "0.0.1-1"
  spec.summary = "type striction"
  spec.author = "wanabe"
  spec.email = "s.wanabe@gmail.com"
  #spec.homepage = ""
  #spec.autorequire = "cool"
  spec.files = Dir.glob("{test,lib}/**/*.rb") << "README" << "ChangeLog"
  spec.test_files = Dir.glob("test/**/*.rb")
  spec.has_rdoc = false
  #spec.rdoc_options << "--main" << "README"
  #spec.extra_rdoc_files = ["README"]
end

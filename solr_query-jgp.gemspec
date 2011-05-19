# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{solr_query-jgp}
  s.version = "1.1.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matthew Rudy Jacobs", "Mark Woods", "Andy Roberts", "Tom Stuart"]
  s.date = %q{2011-05-18}
  s.description = %q{Build SOLR queries, properly escaped, with a nice API}
  s.email = %q{development@jobsgopublic.com}
  s.extra_rdoc_files = ["README"]
  s.files = ["MIT-LICENSE", "Rakefile", "README", "spec", "lib/solr_query.rb"]
  s.homepage = %q{http://github.com/Jobsgopublic/solr_query}
  s.rdoc_options = ["--main", "README"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.7.2}
  s.summary = %q{a ruby library designed to make building nested Solr queries simple and standardized.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end

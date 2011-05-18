unless nil.respond_to?(:blank?)
  require File.join(File.dirname(__FILE__), "blank")
end

module SolrQuery
  class << self
    # build a query for solr
    #
    #   SolrQuery.build(:keyword => "Feather duster")
    #   => "feather duster"
    #
    #   SolrQuery.build(:keyword => "clean", :organisation => [organisation1, organisation2])
    #   => "clean AND organisation:(275 OR 6534)"
    #
    #   SolrQuery.build(:colour => ["red", "pink"], :item_type => ["Toy", "Train"])
    #   => "colour:(red OR pink) AND item_type:(Toy OR Train)"
    #
    # or you can specify a different magical key for keyword;
    #
    #   SolrQuery.build({:keyword => "old one", :new_keyword => "new one"}, {:keyword_key => :new_keyword})
    #   => "new one AND keyword:(old one)"
    # if you need to do range queries;
    #
    #   SolrQuery.build(:salary => {:min => "010000", :max => "050000"})
    #   => "salary:(010000 TO 050000)"
    #
    #   SolrQuery.build(:salary => "010000".."050000")
    #   => "salary:(010000 TO 050000)"
    #
    #   SolrQuery.build(:surname => {:min => "jacobs")
    #   => "surname:(jacobs TO *)"
    def build(conditions = {}, opts={})
      conditions = conditions.dup # let's not accidentally kill our original params
      opts = opts.dup
      opts[:keyword_key] ||= :keyword
      opts[:keyword_boost] ||= nil # field name in which keyword relvance should be boosted (via a disgusting hack)
      opts[:keyword_proximity] ||= 1000 # term proximity required to boost scores based on proximity, see http://wiki.apache.org/solr/SolrRelevancyCookbook
      query_parts = []
      keyword = conditions.delete(opts[:keyword_key]) # keyword is magical
      keyword = solr_value(keyword, true, false)
      unless keyword.blank?
        if keyword.include?(' OR ') || keyword.include?(' AND ')
          # backwards compatibility - don't mess with keywords that already contain boolean operators (which effectively means don't mess with keywords provided as an array)
          query_parts << "#{keyword}"
        else
          if keyword.include?(' ')
            # Find multiple keywords near each other, but also allow for keywords/phrase that ends with "in <some location>".
            # If keyword provided contains " in ", words before the in are considered to be the keywords that need to
            # be near each other in the text, words after the in are considered location(s) that can appear anywhere.
            phrases = keyword.split(' in ') # split keywords in general keywords and location keywords
            proximity = opts[:keyword_proximity].to_i / phrases.size # if we have both general and location keywords, each set should be nearer each other
            query_parts << "text:\"#{phrases.shift}\"~#{proximity}" # general keywords
            query_parts << "text:\"#{phrases.join(' ')}\"~#{proximity}" unless phrases.empty? # other (i.e. location) keywords
          else
            query_parts << "#{keyword}"
          end
          if opts[:keyword_boost]
            # Index time boosting not working, so boost score for matches in boost field by explicitly looking for each keyword in that field
            query_parts[0] = "(" + query_parts[0] + " OR (" + keyword.split(/\s+/).map{|k| "#{opts[:keyword_boost]}:#{k}"}.join(' AND ') + "))"
          end
        end
      end

      conditions.each do |field, value|
        unless value.nil?
          query_parts << "#{field}:(#{solr_value(value)})"
        end
      end

      if query_parts.empty?
        return ""
      else
        return query_parts.join(" AND ")
      end
    end
    
    protected

    def solr_value(object, downcase=false, clean=false)
      if object.is_a?(Array) # case when Array will break for has_manys
        if object.empty?
          string = "NIL" # an empty array should be equivalent to "don't match anything"
        else
          string = object.map do |element|
            solr_value(element, downcase, clean)
          end.delete_if{|element| element.blank?}.join(" OR ")
          downcase = false # don't downcase the ORs
        end
      elsif object.is_a?(Hash) || object.is_a?(Range)
        return solr_range(object) # avoid escaping the *
      elsif defined?(ActiveRecord) && object.is_a?(ActiveRecord::Base)
        string = object.id.to_s
      elsif object.is_a?(String)
        if downcase && object =~ /\s(OR|AND)\s/
          string = solr_value(object.gsub(/\s(OR|AND)\s/,'__\1__'), true, clean)
          string.gsub!('__or__',' OR ')
          string.gsub!('__and__',' AND ')
          if !clean && string.include?('(') && string.include?(')') && ( string.scan('(').size == string.scan(')').size )
            # equal number of opening and closing brackets, un-escape them (yeah, it's not perfect, but it'll do)
            string.gsub!(/\\+(\(|\))/,'\1')
          end
          return '(' + string + ')'
        else
          string = object
        end
      else
        string = object.to_s
      end
      string.downcase! if downcase
      return clean ? clean_solr_string(string) : escape_solr_string(string)
    end

    def solr_range(object)
      min = max = nil
      if object.is_a?(Hash)
        min = object[:min]
        max = object[:max]
      else
        min = object.first
        max = object.last
      end
      min = solr_value(min) if min
      max = solr_value(max) if max

      min ||= "*"
      max ||= "*"

      return "[#{min} TO #{max}]"
    end

    def clean_solr_string(str)
      str.gsub(RE_ESCAPE_LUCENE,'').gsub(/\s+/,' ').strip
    end 
    
    def escape_solr_string(str)
      str.gsub(RE_ESCAPE_LUCENE) { |m| "\\#{m}" }.gsub(/\s+/,' ').gsub(ENDING_KEYWORDS) { |w| w.downcase }.strip
    end   
  end

  # The Lucene documentation declares special characters to be:
  #   + - && || ! ( ) { } [ ] ^ " ~ * ? : \
  # and I've added a semi-colon, because I find them offensive ;-)
  # note: this nice code comes from Jeremy Voorhis's Lucene query builder at http://github.com/jvoorhis/lucene_query
  RE_ESCAPE_LUCENE = /
    ( [-+!\(\)\{\}\[\]^"~*?:;\\] # A special character
    | &&                         # Boolean &&
    | \|\|                       # Boolean ||
    )
  /x 
  
  ENDING_KEYWORDS = /(AND$ | OR$ | NOT$)/x

end

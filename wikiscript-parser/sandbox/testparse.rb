require 'strscan'
require 'pp'


def skip_whitespaces( input )  ## incl. multiple newlines
  return 0   if input.eos?

  input.scan( /[ \t\r\n]*/ )
end



#
# Whereas MediaWiki variable names are all uppercase,
# template names have the same basic features and limitations as all page names:
# they are case-sensitive (except for the first character);
# underscores are parsed as spaces;
# and they cannot contain any of these characters: # < > [ ] | { }.
# This is because those are reserved for wiki markup and HTML.

TEMPLATE_BEGIN_RE = /\{\{/  ## e.g  {{
TEMPLATE_END_RE   = /\}\}/  ## e.g. }}

## todo/fix: check how to add # too!!!
##  todo: check what chars to escape in character class
##  change to something line [^|<>\[\]{}]+ ]
TEMPLATE_NAME_RE = /[a-z0-9 _-]+/i





module Wikitree
class Template
  ### add "built-in" template functions
  def _increase()
    " <UP> "
  end

  def _cite_web( *args, **kwargs )
    " <CITE_WEB> "
  end

  def _note( *args )
    " <NOTE> "
  end

  def _ref_label( *args )
    " <REF_LABEL> "
  end
end # class Template
end # module Wikitree




def parse_template( input )
  input.scan( TEMPLATE_BEGIN_RE ) ## e.g.{{
  skip_whitespaces( input )

  name = input.scan( TEMPLATE_NAME_RE )
  name = name.strip  ## strip trailing spaces?
  puts "==> (begin) template >#{name}<"
  skip_whitespaces( input )

  params = []
  loop do
     if input.check( TEMPLATE_END_RE ) ## e.g. }}
       input.scan( TEMPLATE_END_RE )
       puts "<== (end) template >#{name}<"
       ## puts "  params:"
       ## pp params
       return Template.new( name, params )
     elsif input.check( /\|/ )  ## e.g. |
       puts "      param #{params.size+1} (#{name}):"
       param_name, param_value = parse_param( input )
       params << [param_name, param_value]
     else
       puts "!! SYNTAX ERROR: expected closing }} or para | in template:"
       puts input.peek( 100 )
       exit 1
     end
  end
end



def parse_param( input )
  input.scan( /\|/ )
  skip_whitespaces( input )

  name  = nil
  value = []    # note: value is an array of ast nodes!!!

  ## check for named param e.g. hello=
  ##  otherwise assume content
  if input.check( /[a-z0-9 _-]+(?==)/i )  ## note: use positive lookhead (=)
    name = input.scan( /[a-z0-9 _-]+/i )
    name = name.strip  ## strip trailing spaces?
    puts "        param name >#{name}<"
    input.scan( /=/ )
    skip_whitespaces( input )

    if input.check( /\|/ ) ||
       input.check( /\}/ )  ## add/allow }} too? - why? why not?
      ## allow empty value!!!
      puts "!! WARN: empty value for param >#{name}<"
    else
      value = parse_param_value( input )  ## get keyed param value
      puts "        param value >#{value}<"
    end
  else
    if input.check( /\|/ ) ||   ## add/allow }} too? - why? why not?
       input.check( /\}/ )
      ## allow empty value here too - why? why not?
      puts "!! WARN: empty value for (unnamed/positioned) param"
    else
      value = parse_param_value( input )  ## get (unnamed) param value
      puts "        param value >#{value}<"
    end
  end
  [name, value]
end


def parse_param_value( input )
  # puts "     [debug] parse_param_value >#{input.peek(10)}...<"

  values = []
  loop do
    values << parse( input )
    skip_whitespaces( input )

    ## puts "      [debug] peek >#{input.peek(10)}...<"
    if input.check( /\|/ ) || input.check( /\}\}/ )
      ## puts "        [debug] break param_value"
      break
    end

    if input.eos?
      puts "!! SYNTAX ERROR: unexpected end of string in param value; expected ending w/ | or }}"
      exit 1
    end
  end

  values
end


def parse_link( input )
  input.scan( /\[\[/ )

  ## page name
  name     = input.scan( /[^|\]]+/ ).strip
  alt_name = if input.check( /\|/ )  ## optional alternate/display name
                input.scan( /\|/ )  ## eat up |
                input.scan( /[^\]]+/ ).strip
             else
                nil
             end

  input.scan( /\]\]/ )  ## eatup ]]
  skip_whitespaces( input )

  if alt_name
    puts " @page<#{name} | #{alt_name}>"
  else
    puts " @page<#{name}>"
  end

  Page.new( name, alt_name )
end


def parse( input )
  ## puts "  [debug] parse >#{input.peek(10)}...<"
  if input.check( TEMPLATE_BEGIN_RE )
    parse_template( input )
  elsif input.check( /\[\[/ )
    parse_link( input )
  elsif input.check( /[^|{}\[\]]+/ )    ## check for rawtext run for now
    run = input.scan( /[^|{}\[\]]+/ ).strip
    # puts "   text run=>#{run}<"
    Text.new( run )
  else
    puts " !! SYNTAX ERROR: unknown content type:"
    puts input.peek( 100 )
    exit 1
  end
end



def parse_lines( text )
  ## note: remove all html comments for now - why? why not?
  ## <!-- Area rank should match .. -->
  text = text.gsub( /<!--.+?-->/m ) do |m|  ## note: use .+? (non-greedy match)
                                       puts " removing comment >#{m}<"
                                       ''
                                     end

  input = StringScanner.new( text )

  nodes = []
  loop do
    skip_whitespaces( input )
    break if input.eos?

    nodes << parse( input )
 end
 nodes
end




path = './infoboxes/en/Austria.txt'
## path = './infoboxes/en/Belgium.txt'

text = File.open( path, 'r:utf-8') { |f| f.read }

puts text[0..200]
puts

nodes = parse_lines( text )
puts "#{nodes.size} node(s):"
pp nodes

infobox = nodes[0]


puts "#{infobox.name} - #{infobox.params.size} param(s):"

infobox.params.each_with_index do |param,i|
  puts "  [#{i+1}] #{param.name}:"
  puts "text: #{param.to_text}"
  puts "source: #{param.to_wiki}"
  puts
end

puts "bye"

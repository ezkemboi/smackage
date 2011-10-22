
(*
    This defines the data structure and syntax for smackage package definitions (smackspec files).
    The general syntax is a flat key/value format, eg.

        provides: test 1.2.3beta
        description:
            This is a sample smackspec file.

        requires: smacklib >= 1.2.3
        requires: ioextras 0.0.45

    Lines that aren't indented or empty must contain a key name followed by a colon (with no whitspace before the colon).
    The string to the right of the colon as well as any following indented or empty lines constitutes the value belonging
    to that key. There is no order and keys may occur multiple times. Lines with only whitespace at the beginning of the
    file are ignored. Keys that have no meaning in smackspec are syntax errors.
    
    The values have further syntactic restrictions depending on the key, vaguely summerized here:
    
        provides: PACKAGE_NAME SEMANTIC_VERSION     (exactly once)
        description: ANY_STRING                     (at most once)
        requires: PACKAGE_NAME VERSION_CONSTRAINTS  (zero or more)
        comment: ANY_STRING                         (zero or more, thrown away while parsing)
*)

signature SPEC =
sig

    exception Error of string

    type position

    type packageName

    type requirement

    type package
    
    type description
    
    type smackspec
    
    val fromFile : string -> smackspec

    val fromString : string -> smackspec
    
end


structure Spec : SPEC =
struct

    exception Error of string

    type position = int

    type packageName = string

    type requirement = packageName * SemVer.constraint * position

    type package = packageName * SemVer.semver * position
    
    type description = string * position
    
    type unparsed = string * position
    
    type smackspec = {
        provides : package,
        description : description option,
        requires : requirement list,
        maintainer : unparsed option,
        upstreamVersion : unparsed option,
        upstreamUrl : unparsed option,
        git : unparsed option,
        svn : unparsed option,
        hg : unparsed option,
        cvs : unparsed option,
        documentationUrl : unparsed option,
        bugUrl : unparsed option,
        license : unparsed option,
        platform : unparsed option,
        build : unparsed option,
        test : unparsed option,
        install : unparsed option,
        uninstall : unparsed option,
        documentation : unparsed option
        }

         
    datatype directive
        = Comment
        | Provides of package
        | Description of description
        | Requires of requirement
        | Unparsed of string * string * position

        
    fun dropWhile' predicate ([], count) = ([], count)
      | dropWhile' predicate ((head :: tail), count) = 
            if predicate head
                then dropWhile' predicate (tail, count + 1)
                else (head :: tail, count)

    fun dropWhile predicate list = #1 (dropWhile' predicate (list, 0))

    
    fun parseDirectives keyValues = 
        let
        
            fun parse (key, value, position) = case key of
                  "comment" => Comment
                | "description" => Description (value, position)
                | "maintainer" => Unparsed (key, value, position)
                | "keywords" => Unparsed (key, value, position)
                | "upstream-version" => Unparsed (key, value, position)
                | "upstream-url" => Unparsed (key, value, position)
                | "git" => Unparsed (key, value, position)
                | "svn" => Unparsed (key, value, position)
                | "hg" => Unparsed (key, value, position)
                | "cvs" => Unparsed (key, value, position)
                | "documentation-url" => Unparsed (key, value, position)
                | "bug-url" => Unparsed (key, value, position)
                | "license" => Unparsed (key, value, position)
                | "platform" => Unparsed (key, value, position)
                | "build" => Unparsed (key, value, position)
                | "test" => Unparsed (key, value, position)
                | "install" => Unparsed (key, value, position)
                | "uninstall" => Unparsed (key, value, position)
                | "documentation" => Unparsed (key, value, position)
                | "provides" => 
                    let
                        val [packageName, version] = String.tokens Char.isSpace value
                    in
                        Provides (packageName, SemVer.fromString version, position)
                    end
                | "requires" => 
                    let
                        val (packageName :: constraint) = String.tokens Char.isSpace value
                    in
                        Requires (packageName, String.concatWith " " constraint, position)
                    end
                | keyword => raise Error ("Unknown directive '" ^ keyword ^ "' on line " ^ Int.toString position)
            
            val directives = map parse keyValues
            
            val providesDirectives = List.mapPartial (fn (Provides directive) => SOME directive | _ => NONE) directives
            val provides = case providesDirectives of
                  [] => raise Error ("A 'provides' directive is required, eg: provides: mypackage 0.2.5")
                | [directive] => directive
                | (_ :: (_, _, position) :: _) => raise Error ("Only one 'provides' directive is allowed, but a second one is specified on line " ^ Int.toString position)
            
            val descriptionDirectives = List.mapPartial (fn (Description directive) => SOME directive | _ => NONE) directives
            val description = case descriptionDirectives of
                  [] => NONE
                | [directive] => SOME directive
                | (_ :: (_, position) :: _) => raise Error ("At most one 'description' directive is allowed, but a second one is specified on line " ^ Int.toString position)

            val requires = List.mapPartial (fn (Requires directive) => SOME directive | _ => NONE) directives
            
            fun unparsed key = 
                let
                    val directives' = List.mapPartial (fn (Unparsed (key', value, position)) => if key' = key then SOME (value, position) else NONE | _ => NONE) directives
                in
                    case directives' of
                          [] => NONE
                        | [directive] => SOME directive
                        | (_ :: (_, position) :: _) => raise Error ("At most one '" ^ key ^ "' directive is allowed, but a second one is specified on line " ^ Int.toString position)
                end
                
        in
            {
                provides = provides,
                description = description,
                requires = requires,
                maintainer = unparsed "maintainer",
                upstreamVersion = unparsed "upstream-version",
                upstreamUrl = unparsed "upstream-url",
                git = unparsed "git",
                svn = unparsed "svn",
                hg = unparsed "hg",
                cvs = unparsed "cvs",
                documentationUrl = unparsed "documentation-url",
                bugUrl = unparsed "bug-url",
                license = unparsed "license",
                platform = unparsed "platform",
                build = unparsed "build",
                test = unparsed "test",
                install = unparsed "install",
                uninstall = unparsed "uninstall",
                documentation = unparsed "documentation"
            }
        end
    

    fun parseKeyValues lines =
        let

            fun parseKeyLine line = 
                let
                    val (key :: valueParts) = String.fields (fn c => c = #":") line
                in
                    (key, String.concatWith ":" valueParts)
                end
            
            fun parseValueLines (lines : (string * position) list) = 
                let
                    fun isValueLine (line, _) = String.size line = 0 orelse 
                        let
                            val c = String.sub (line, 0)
                        in
                            c = #"\r" orelse c = #"\n" orelse c = #" " orelse c = #"\t"
                        end
                        
                    val (lines', count) = dropWhile' isValueLine (lines, 0)
                in
                    (List.take (lines, count), lines')
                end

            fun parse ([], keyValues) = rev keyValues
              | parse ((line, position) :: lines, keyValues) = 
                    let
                        val (key, valueHead) = parseKeyLine line
                        val (valueTail, lines') = parseValueLines lines
                        val keyValue = (key, concat (valueHead :: map #1 valueTail), position)
                    in
                        parse (lines', keyValue :: keyValues)
                    end
                    
            val lines' = dropWhile (fn (line, _) => CharVector.all Char.isSpace line) lines
        in
            parse (lines', [])
        end 
    

    fun readLines (file, position, lines) = 
        case TextIO.inputLine file of
              NONE => rev lines
            | (SOME line) => readLines (file, position + 1, (line, position) :: lines)


    fun parseStream stream = 
        let
            val lines = readLines (stream, 1, [])
            val keyValues = parseKeyValues lines
        in
            parseDirectives keyValues
        end

    fun fromFile filename =
        let
            val file = TextIO.openIn filename
            val result = parseStream file
            val _ = TextIO.closeIn file
        in
            result
        end

    fun fromString string = parseStream (TextIO.openString string)

end

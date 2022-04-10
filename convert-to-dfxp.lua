-- Copyright (c) 2022, Yuri Petnys <yuri.oliveira@gmail.com>
--
-- Permission to use, copy, modify, and distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
-- ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
-- ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
-- OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

local tr = aegisub.gettext

unicode = require 'unicode'

script_name = tr"Convert to DFXP"
script_description = tr"Converts the script to DFXP"
script_author = "Yuri Petnys"
script_version = "1.02"

function format_time(t)
    ms = t % 1000
    t = (t - ms)/1000
    s = t % 60
    t = (t - s)/60
    m = t % 60
    t = (t - m)/60
    h = t
    
    return string.format("%02d:%02d:%02d.%03d", h, m, s, ms)
end

function is_value_on_table(v, t)
    for i = 1, #t do
        if v == t[i] then
            return true
        end
    end
    
    return false
end

STYLE_OPTION_ENUM = { "Dialogue", "Signs", "Ignore" }

function show_styles_dialogue(subs)
    config = { {class="label", label="Configure how to process each style:", x=0, y=0} }
    
    y = 1
    for i = 1, #subs do
        if subs[i].class == "style" then
            table.insert(config, {class="label", label=subs[i].name, x=0, y=y} )
            table.insert(config, {class="dropdown", name=subs[i].name, items=STYLE_OPTION_ENUM, value=STYLE_OPTION_ENUM[1], x=1, y=y} )
            y = y + 1
        end
    end
    
    btn, style_options = aegisub.dialog.display(config, {"OK", "Cancel"}, {["ok"] = "OK", ["cancel"] = "Cancel"})
    if btn == "Cancel" then aegisub.cancel() end
    
    return style_options
end

function convert_to_dfxp(subs, sel)
    -- Ask which styles are dialogue styles
    style_options = show_styles_dialogue(subs)

    -- Ask where to save the file
    proposed_fn = aegisub.file_name():gsub("%.ass", ".dfxp")
    file_name = aegisub.dialog.save("Export subtitle as DFXP", proposed_fn, "", "DFXP Files (.dfxp)|*.dfxp", false)
    if not file_name then aegisub.cancel() end
        
    -- Write header
    file = io.open(file_name, "w")
    file:write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
    file:write("<tt xmlns=\"http://www.w3.org/ns/ttml\" xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\" xmlns:tts=\"http://www.w3.org/ns/ttml#styling\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xml:lang=\"en\">\n")
    file:write("  <head>\n")
    file:write("    <metadata>\n")
    file:write("      <ttm:title>" .. file_name .. "</ttm:title>\n")
    file:write("    </metadata>\n")
    file:write("    <styling>\n")
    file:write("      <style tts:fontStyle=\"normal\" tts:fontWeight=\"normal\" xml:id=\"s1\" tts:color=\"white\" tts:fontFamily=\"Arial\" tts:fontSize=\"100%\"></style>\n")
    file:write("    </styling>\n")
    file:write("    <layout>\n")
    file:write("      <region tts:extent=\"80% 40%\" tts:origin=\"10% 10%\" tts:displayAlign=\"before\" tts:textAlign=\"center\" xml:id=\"topCenter\" />\n")
    file:write("      <region tts:extent=\"80% 40%\" tts:origin=\"10% 50%\" tts:displayAlign=\"after\" tts:textAlign=\"center\" xml:id=\"bottomCenter\" />\n")
    file:write("    </layout>\n")
    file:write("  </head>\n")
    file:write("  <body>\n")
    file:write("    <div style=\"s1\" xml:id=\"d1\">\n")
    
    -- Processes every dialogue line
    j = 1
    for i = 1, #subs do
        aegisub.progress.set(i * 100 / #subs)
        if subs[i].class == "dialogue" and not subs[i].comment and subs[i].text ~= "" then
            
            -- Formats timestamps to dfxp format
            pstart = format_time(subs[i].start_time)
            pend = format_time(subs[i].end_time)

            -- Replaces \N with <br/>, removes ASS tags
            ptext = subs[i].text:gsub("{.-}","")
            
            -- If it's a dialogue line, just convert linebreaks to <br/>
            -- If it's not dialogue, it's a typeset line - remove all line breaks and capitalize everything
            if style_options[subs[i].style] ~= "Ignore" then
                if style_options[subs[i].style] == "Dialogue" then
                    ptext = ptext:gsub("\\N","<br/>")
                    pregion = "bottomCenter"
                elseif style_options[subs[i].style] == "Signs" then
                    ptext = ptext:gsub("\\N"," ")
                    ptext = ptext:gsub(" +"," ")
                    ptext = unicode.to_upper_case(ptext)
                    -- pregion = "topCenter"
                    pregion = "bottomCenter"
                end
                
                file:write("      <p xml:id=\"p" .. j .. "\" begin=\"" .. pstart .. "\" end=\"" .. pend .. "\" region=\"" .. pregion .. "\">" .. ptext .. "</p>\n")
                j = j + 1
            end 
            
        end
    end
    
    -- Writes footer
    file:write("    </div>\n")
    file:write("  </body>\n")
    file:write("</tt>")
    file:close()
end

aegisub.register_macro(script_name, script_description, convert_to_dfxp)


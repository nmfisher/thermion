file(READ ${INPUTFILE} INPUT_TEXT)

foreach(TO_REPLACE_STRING ${TO_REPLACE})

    #get the index of the current to_replace string
    list(FIND TO_REPLACE ${TO_REPLACE_STRING} REPLACE_INDEX)
    
    #look up the corresponding replacement string
    list(GET REPLACEMENT ${REPLACE_INDEX} REPLACEMENT_STRING)

    string(REPLACE ${TO_REPLACE_STRING} ${REPLACEMENT_STRING} INPUT_TEXT "${INPUT_TEXT}")
endforeach()

file(WRITE ${OUTPUTFILE} "${INPUT_TEXT}")
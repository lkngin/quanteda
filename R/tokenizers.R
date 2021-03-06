# man page ----------

#' quanteda tokenizers
#'
#' Internal methods for tokenization providing default and legacy methods for
#' text segmentation.
#' @name tokenize_internal
#' @rdname tokenize_internal
#' @aliases tokenize
#' @param x (named) character; input texts
#' @return a list of characters corresponding to the (most conservative)
#'   tokenization, including whitespace where applicable; except for
#'   `tokenize_word1()`, which is a special tokenizer for Internet language that
#'   includes URLs, #hashtags, @usernames, and email addresses.
#' @keywords tokens internal
#' @examples
#' \dontrun{
#' txt <- c(doc1 = "Tweet https://quanteda.io using @quantedainit and #rstats.",
#'          doc2 = "The £1,000,000 question.",
#'          doc4 = "Line 1.\nLine2\n\nLine3.",
#'          doc5 = "?",
#'          doc6 = "Self-aware machines! \U0001f600")
#' tokenize_word(txt)
#' tokenize_word(txt, split_hyphens = TRUE)
#' tokenize_word2(txt, split_hyphens = FALSE)
#' tokenize_word2(txt, split_hyphens = TRUE)
#' tokenize_fasterword(txt)
#' tokenize_fastestword(txt)
#' tokenize_sentence(txt)
#' tokenize_character(txt[2])
#' }
NULL

# improved tokenizer ----------

#' @rdname tokenize_internal
#' @importFrom stringi stri_replace_all_regex stri_detect_fixed stri_split_boundaries
#' @export
tokenize_word <- function(x, split_hyphens = FALSE, verbose = quanteda_options("verbose")) {
    
    if (verbose) catm(" ...segmenting tokens\n")
    m <- names(x)
    x[is.na(x)] <- "" # make NAs ""
    
    # this will not be needed if we can modify the ICU type rules to protect them
    # remove variant selector & whitespace with diacritical marks
    x <- stri_replace_all_regex(x, c("[\uFE00-\uFE0F]", "\\s[\u0300-\u036F]"), "",
                                vectorize_all = FALSE)

    structure(stri_split_boundaries(x, type = "word"), names = m)
}

preserve_special <- function(x, split_hyphens = TRUE, split_tags = TRUE, verbose = FALSE) {
    
    name <- names(x)
    x <- as.character(x)
    
    hyphen <- "[\\p{Pd}]"
    username <- quanteda_options("pattern_username") 
    hashtag <- quanteda_options("pattern_hashtag")
    # preserves web and email address
    address <- "(https?:\\/\\/(www\\.)?|@)[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-z]{2,4}\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*)"

    regex <- address
    if (!split_hyphens) {
        if (verbose) catm(" ...preserving hyphens\n")
        regex <- c(regex, hyphen)
    }
    if (!split_tags) {
        if (verbose) catm(" ...preserving social media tags (#, @)\n")
        regex <- c(regex, username, hashtag)
    }
    
    s <- stri_extract_all_regex(x, paste(regex, collapse = "|"),  omit_no_match = TRUE)
    r <- lengths(s)
    s <- unlist(s, use.names = FALSE)
    
    # index specials
    u <- unique(s)
    u <- u[order(stri_length(u), decreasing = TRUE)] # substitute longer match first
    index <- split(rep(seq_along(x), r), factor(s, levels = u))
    if (length(index)) {
        special <- paste0("\u100000", seq_along(index), "\u100001")
        names(special) <- names(index)
        for (i in seq_along(index)) {
            x[index[[i]]] <- stri_replace_all_fixed(
                x[index[[i]]], 
                names(special)[i], 
                special[i],
                vectorize_all = FALSE
            )
        }
    } else {
        special <- character()
    } 
    structure(x, names = name, special = special)
}

restore_special <- function(x, special) {

    if (!length(special))
        return(x)
    
    types <- types(x)
    # extract all placeholders
    d <- stri_extract_all_regex(types, "\u100000\\d+\u100001", omit_no_match = TRUE)
    r <- lengths(d)
    d <- unlist(d, use.names = FALSE)
    
    # index placeholders
    index <- split(rep(seq_along(types), r), factor(d, levels = unique(d)))
    if (length(index)) {
        pos <- fastmatch::fmatch(names(index), special)
        for (i in seq_along(index)) {
            types[index[[i]]] <- stri_replace_all_fixed(
                types[index[[i]]], 
                special[pos[i]], 
                names(special)[pos[i]],
                vectorize_all = FALSE
            )
        }
    }
    if (!identical(types, types(x))) {
        types(x) <- types
        x <- tokens_recompile(x)
    }
    return(x)
}


# legacy tokenizers ----------

#' @rdname tokenize_internal
#' @inheritParams tokens
#' @importFrom stringi stri_detect_regex stri_detect_charclass
#'   stri_replace_all_regex stri_detect_fixed stri_replace_all_fixed
#' @export
tokenize_word1 <- function(x, split_hyphens = FALSE, verbose = quanteda_options("verbose")) {
    
    m <- names(x)
    x[is.na(x)] <- "" # make NAs ""

    # remove variant selector & whitespace with diacritical marks
    x <- stri_replace_all_regex(x, c("[\uFE00-\uFE0F]", "\\s[\u0300-\u036F]"), "",
                                vectorize_all = FALSE)
    # substitute characters not to split
    x <- preserve_special1(x, split_hyphens = split_hyphens, split_tags = TRUE, verbose = verbose)

    if (verbose) catm(" ...segmenting texts\n")
    structure(stri_split_boundaries(x, type = "word"), names = m)
}

# substitutions to preserve hyphens and tags
preserve_special1 <- function(x, split_hyphens = TRUE, split_tags = TRUE, verbose = FALSE) {
    if (!split_hyphens) {
        if (verbose) catm(" ...preserving hyphens\n")
        x <- stri_replace_all_regex(x, "(\\w)\\p{Pd}+", "$1_hy_")
    }
    if (!split_tags) {
        if (verbose) catm(" ...preserving social media tags (#, @)\n")
        x <- stri_replace_all_fixed(x, c("#", "@"), c("_ht_", "_as_"), vectorize_all = FALSE)
    }
    return(x)
}

# re-substitute the replacement hyphens and tags
restore_special1 <- function(x, split_hyphens = TRUE, split_tags = TRUE, verbose) {
    types <- types(x)
    if (!split_hyphens)
        types <- stri_replace_all_fixed(types, "_hy_", "-")
    if (!split_tags)
        types <- stri_replace_all_fixed(types, c("_ht_", "_as_"), c("#", "@"),
                                        vectorize_all = FALSE)
    if (!identical(types, types(x))) {
        types(x) <- types
        x <- tokens_recompile(x)
    }
    return(x)
}

#' @rdname tokenize_internal
#' @importFrom stringi stri_split_boundaries
#' @export
tokenize_character <- function(x, ...) {
    stri_split_boundaries(x, type = "character", simplify = FALSE)
}

#' @rdname tokenize_internal
#' @importFrom stringi stri_replace_all_regex stri_replace_all_fixed
#'   stri_split_boundaries stri_trim_right
#' @export
tokenize_sentence <- function(x, ..., verbose = FALSE) {
    if (verbose) catm(" ...segmenting into sentences.\n")
    named <- names(x)

    # Replace . delimiter from common title abbreviations, with _pd_
    exceptions <- c("Mr", "Mrs", "Ms", "Dr", "Jr", "Prof", "Ph.D", "M", "MM", "St", "etc")
    findregex <- paste0("\\b(", exceptions, ")\\.")
    x <- stri_replace_all_regex(x, findregex, "$1_pd_", vectorize_all = FALSE)

    ## Remove newline chars
    x <- lapply(x, stri_replace_all_fixed, "\n", " ")

    ## Perform the tokenization
    tok <- stri_split_boundaries(x, type = "sentence")

    ## Cleaning
    tok <- lapply(tok, function(x) {
        x <- x[which(x != "")] # remove any "sentences" that were completely blanked out
        x <- stri_trim_right(x) # trim trailing spaces
        x <- stri_replace_all_fixed(x, "_pd_", ".") # replace the non-full-stop "." characters
        return(x)
    })
    names(tok) <- named
    return(tok)
}

#' @rdname tokenize_internal
#' @importFrom stringi stri_split_regex
#' @export
tokenize_fasterword <- function(x, ...) {
    stri_split_regex(x, "[\\p{Z}\\p{C}]+")
}

#' @rdname tokenize_internal
#' @importFrom stringi stri_split_regex
#' @export
tokenize_fastestword <- function(x, ...) {
    stri_split_regex(x, " ")
}

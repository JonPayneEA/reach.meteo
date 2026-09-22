# ============================================================
# Tool: Public S3 utilities
# Description: Lists public object keys with pagination and retry handling.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Bucket endpoint and object prefix.
# Outputs: A data.table object manifest.
# Dependencies: httr2; xml2; data.table.
# ============================================================


.read_xml_child <- function(node, child_name) {
  child <- xml2::xml_find_first(
    node,
    paste0("./*[local-name()='", child_name, "']")
  )
  if (inherits(child, "xml_missing")) return(NA_character_)
  xml2::xml_text(child)
}

.list_s3_objects <- function(endpoint, prefix, max_keys = 1000L) {
  pages <- list()
  continuation_token <- NULL

  repeat {
    request <- httr2::request(endpoint) |>
      httr2::req_url_query(
        `list-type` = "2",
        prefix = prefix,
        `max-keys` = as.character(max_keys)
      )
    if (!is.null(continuation_token)) {
      request <- request |>
        httr2::req_url_query(`continuation-token` = continuation_token)
    }

    document <- request |>
      httr2::req_retry(max_tries = 5) |>
      httr2::req_perform() |>
      httr2::resp_body_string() |>
      xml2::read_xml()

    nodes <- xml2::xml_find_all(document, ".//*[local-name()='Contents']")
    if (length(nodes)) {
      page_dt <- data.table::data.table(
        object_key = vapply(nodes, .read_xml_child, character(1), child_name = "Key"),
        size_bytes = as.numeric(vapply(nodes, .read_xml_child, character(1), child_name = "Size")),
        last_modified = as.POSIXct(
          vapply(nodes, .read_xml_child, character(1), child_name = "LastModified"),
          tz = "UTC"
        )
      )
      data.table::setnames(page_dt, "object_key", "key")
      pages[[length(pages) + 1L]] <- page_dt
    }

    truncated_node <- xml2::xml_find_first(document, ".//*[local-name()='IsTruncated']")
    truncated <- !inherits(truncated_node, "xml_missing") &&
      identical(tolower(xml2::xml_text(truncated_node)), "true")
    if (!truncated) break

    token_node <- xml2::xml_find_first(document, ".//*[local-name()='NextContinuationToken']")
    if (inherits(token_node, "xml_missing")) {
      stop("S3 response was truncated but supplied no continuation token.", call. = FALSE)
    }
    continuation_token <- xml2::xml_text(token_node)
  }

  if (!length(pages)) {
    empty_dt <- data.table::data.table(
      object_key = character(),
      size_bytes = numeric(),
      last_modified = as.POSIXct(character(), tz = "UTC")
    )
    data.table::setnames(empty_dt, "object_key", "key")
    return(empty_dt)
  }
  data.table::rbindlist(pages, use.names = TRUE, fill = TRUE)
}

.encode_s3_key <- function(key) {
  parts <- strsplit(key, "/", fixed = TRUE)[[1L]]
  paste(vapply(parts, utils::URLencode, character(1), reserved = TRUE), collapse = "/")
}

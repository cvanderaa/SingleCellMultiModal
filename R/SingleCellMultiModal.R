.internalMap <- S4Vectors::DataFrame(
    FUN = c("scNMT", "scMultiome", "SCoPE2",
        "CITEseq", "CITEseq", "seqFISH"),
    DataType = c("mouse_gastrulation", "pbmc_10x",
        "macrophage_differentiation", "cord_blood",
        "peripheral_blood", "mouse_visual_cortex"
    )
)

.filterMap <- function(DataTypes, dry.run, verbose) {
    inDTypes <- match(DataTypes, .internalMap[["DataType"]])
    notfound <- is.na(inDTypes)
    if (any(notfound))
        stop("'", paste(DataTypes[notfound], collapse = ", "),
            "' is not available, ", "see ?SingleCellMultiModal")
    upmap <- .internalMap[inDTypes, , drop = FALSE]
    upmap[["dry.run"]] <- dry.run
    upmap[["verbose"]] <- verbose
    upmap
}

#' Combining Modalities into one MultiAssayExperiment
#'
#' Combine multiple single cell modalities into one using the input of the
#' individual functions.
#'
#' @inheritParams scNMT
#'
#' @param DataTypes character() A vector of data types as indicated in each
#'     individual function by the `DataType` parameter. These can be any of
#'     the following: "mouse_gastrulation", "pbmc_10x",
#'     "macrophage_differentiation", "cord_blood", "peripheral_blood",
#'     "mouse_visual_cortex"
#'
#' @param versions character() A vector of versions for each DataType. By
#'     default, version `1.0.0` is obtained for all data types.
#'
#' @param modes list() A list or CharacterList of modes for each data type
#'     where each element corresponds to one data type.
#'
#' @md
#'
#' @examples
#'
#' SingleCellMultiModal(c("mouse_gastrulation", "pbmc_10x"),
#'     modes = list(c("acc*", "met*"), "rna"),
#'     version = c("2.0.0", "1.0.0"), dry.run = TRUE, verbose = TRUE
#' )
#'
#' @export
SingleCellMultiModal <- function(
        DataTypes, modes = "*", versions = "1.0.0",
        dry.run = TRUE, verbose = TRUE, ...
    )
{
    stopifnot(is.character(DataTypes), is.character(versions))
    if (.isSingleChar(modes) && identical(modes, "*"))
        modes <- c(rep(modes, length(DataTypes)))
    if (.isSingleChar(versions) && identical(versions, "1.0.0"))
        versions <- c(rep(versions, length(DataTypes)))
    resmap <- .filterMap(DataTypes, dry.run, verbose)
    modes <- methods::as(modes, "CharacterList")
    resmap <- cbind(resmap, version = versions, modes = modes)

    ess_lists <- apply(resmap, 1L,
        function(resrow) {
            if (verbose)
                message("Running ", resrow[[1]], "...")
            do.call(get(resrow[[1]]), resrow[-1])
        }
    )
    names(ess_lists) <- DataTypes

    if (dry.run) { return(ess_lists) }

    ## hotfix: remove extra column in sampleMap for merge
    if ("peripheral_blood" %in% names(ess_lists))
        sampleMap(ess_lists[["peripheral_blood"]]) <-
            sampleMap(ess_lists[["peripheral_blood"]])[1:3]

    new_prefix <- paste0(resmap[["DataType"]], "_")
    ess_lists <- Map(function(x, y) {
        if (is(x, "MultiAssayExperiment"))
            names(x) <- paste0(y, names(x))
        x
    }, x = ess_lists, y = new_prefix)

    Reduce(c, ess_lists)
}

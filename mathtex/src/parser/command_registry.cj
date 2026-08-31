package mathtex.parser

public class TexCommandRegistry {
    public static func supports(_name: String): Bool {
        let name = normalize(_name)
        for (command in supportedCommandNames()) {
            if (command == name) {
                return true
            }
        }
        return false
    }

    public static func supportedCommandNames(): Array<String> {
        return [
            "frac", "dfrac", "tfrac", "cfrac", "genfrac", "sqrt",
            "begin", "end", "left", "right", "middle",
            "over", "atop", "brace", "brack", "choose",
            "text", "operatorname", "mathop", "mathrel", "mathord", "mathbin", "mathopen", "mathclose", "mathpunct",
            "mathrm", "mathbb", "mathit", "mathnormal", "mathcal", "mathfrak", "mathsf", "mathtt", "mathbf",
            "boldsymbol", "pmb", "textbf", "textit", "textup", "textmd", "textsf", "texttt", "emph", "hbox", "fbox",
            "blue", "red", "green", "purple", "redA", "textcolor", "color",
            "Huge", "small", "Large", "large", "LARGE", "huge", "tiny", "scriptsize", "footnotesize", "normalsize",
            "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle",
            "overline", "underline", "underbar", "widehat", "widecheck", "widetilde", "overrightarrow", "overleftarrow",
            "overleftrightarrow", "Overrightarrow", "underrightarrow", "underleftarrow", "underleftrightarrow",
            "overbrace", "underbrace", "overbracket", "underbracket", "overgroup", "undergroup",
            "overlinesegment", "underlinesegment", "overleftharpoon", "overrightharpoon", "utilde", "hat", "bar", "vec", "tilde", "dot", "ddot",
            "acute", "grave", "breve", "check", "phantom", "hphantom", "vphantom", "smash", "cancel", "bcancel",
            "xcancel", "sout", "boxed", "xleftarrow", "xrightarrow", "xLeftarrow", "xRightarrow", "xleftrightarrow",
            "xLeftrightarrow", "xhookleftarrow", "xhookrightarrow", "xmapsto", "xrightharpoondown",
            "xrightharpoonup", "xleftharpoondown", "xleftharpoonup", "xrightleftharpoons",
            "xleftrightharpoons", "xlongequal", "xtwoheadrightarrow", "xtwoheadleftarrow", "xtofrom",
            "xrightleftarrows", "xrightequilibrium", "xleftequilibrium", "phase", "colorbox", "fcolorbox", "href", "url", "mathchoice",
            "tag", "includegraphics", "raisebox", "vcenter", "rule", "kern", "mkern", "hspace", "hskip",
            "llap", "rlap", "clap", "mathllap", "mathrlap", "mathclap",
            "bigl", "bigr", "bigm", "big", "Bigl", "Bigr", "Bigm", "Big", "biggl", "biggr", "biggm", "bigg",
            "Biggl", "Biggr", "Biggm", "Bigg",
            "\\", "newline", "cr", "hline", "hdashline", "mathstrut", "limits", "nolimits", "relax",
            "def", "gdef", "edef", "xdef", "newcommand", "renewcommand", "providecommand",
            ";", ",", "!", ":", ">", " ", "thinspace", "medspace", "quad", "qquad", "enspace", "thickspace",
            "negthinspace", "negmedspace", "negthickspace", "space", "nobreakspace", "~",
            "{", "}", "$", "%", "&", "#", "textellipsis", "dots", "ldots", "cdots", "vdots", "KaTeX", "i", "j", "imath", "jmath",
            "ae", "AE", "oe", "OE", "o", "O", "ss", "aa", "AA",
            "alpha", "beta", "gamma", "delta", "epsilon", "varepsilon", "zeta", "eta", "theta", "vartheta", "iota",
            "kappa", "lambda", "mu", "nu", "xi", "rho", "varrho", "sigma", "varsigma", "tau", "upsilon", "phi",
            "varphi", "chi", "pi", "psi", "omega", "Gamma", "Delta", "Theta", "Lambda", "Xi", "Pi", "Sigma",
            "Upsilon", "Phi", "Psi", "Omega",
            "sum", "prod", "coprod", "int", "iint", "iiint", "oint", "oiint", "oiiint",
            "lim", "limsup", "liminf", "sin", "cos", "tan", "log", "ln", "max", "min",
            "cdot", "cdotp", "times", "pm", "mp", "div", "oplus", "otimes", "cup", "cap",
            "land", "wedge", "lor", "vee", "sqcap", "sqcup",
            "doublebarwedge", "divideontimes", "ltimes", "rtimes", "leftthreetimes", "rightthreetimes",
            "curlywedge", "curlyvee", "intercal", "doublecap", "doublecup", "boxtimes", "barwedge", "veebar",
            "leq", "le", "lt", "leqq", "leqslant", "lesssim", "lessapprox", "lnsim", "lnapprox", "precnsim", "precnapprox", "nsim",
            "geq", "ge", "gt", "geqq", "geqslant", "gtrsim", "gtrapprox", "gnsim", "gnapprox", "succnsim", "succnapprox",
            "neq", "ne", "nleq", "ngeq", "cong", "equiv", "approx", "approxeq", "simeq", "backsim", "backsimeq",
            "precsim", "precapprox", "thicksim", "thickapprox", "succsim", "succapprox", "eqsim", "triangleq",
            "sim", "propto", "in", "notin", "subset", "subseteq", "supset", "supseteq",
            "subseteqq", "subsetneq", "subsetneqq", "nsubseteq", "supseteqq", "supsetneq", "supsetneqq", "nsupseteq",
            "sqsubset", "sqsubseteq", "sqsupset", "sqsupseteq",
            "to", "rightarrow", "leftarrow", "longleftarrow", "longrightarrow", "longleftrightarrow",
            "nleftarrow", "nrightarrow", "nleftrightarrow", "uparrow", "downarrow", "updownarrow",
            "nearrow", "searrow", "swarrow", "nwarrow", "dashleftarrow", "dashrightarrow",
            "leftleftarrows", "rightrightarrows", "leftrightarrows", "rightleftarrows",
            "leftarrowtail", "rightarrowtail", "looparrowleft", "looparrowright", "curvearrowleft", "curvearrowright",
            "circlearrowleft", "circlearrowright", "upuparrows", "downdownarrows", "rightsquigarrow", "leftrightsquigarrow",
            "Rightarrow", "Leftarrow", "Longleftarrow", "Longrightarrow", "Longleftrightarrow",
            "nLeftarrow", "nRightarrow", "nLeftrightarrow", "Uparrow", "Downarrow", "Updownarrow",
            "Lleftarrow", "Rrightarrow", "leftrightarrow", "Leftrightarrow",
            "mapsto", "longmapsto", "hookleftarrow", "hookrightarrow", "twoheadleftarrow", "twoheadrightarrow",
            "iff", "implies", "impliedby", "vdash", "dashv", "vDash", "Vdash", "Vvdash", "nvdash", "nvDash", "nVdash", "nVDash",
            "models", "therefore", "because", "neg", "lnot", "top", "bot",
            "bigvee", "bigwedge", "bigcap", "bigcup", "bigoplus", "bigotimes", "bigsqcup", "smallint", "intop",
            "infty", "partial", "nabla", "forall", "exists", "nexists", "emptyset",
            "not", "langle", "rangle", "lparen", "rparen", "lfloor", "rfloor", "lceil", "rceil",
            "llbracket", "rrbracket", "lBrace", "rBrace",
            "lbrace", "rbrace", "lvert", "rvert", "vert", "lVert", "rVert", "Vert", "|", "mid", "lang", "rang",
            "overset", "underset", "injlim", "projlim", "varlimsup", "varliminf", "varinjlim", "varprojlim",
            "plim", "argmin", "argmax", "substack", "mathinner", "angl", "angln",
            "N", "R", "Z", "alef", "alefsym", "empty", "infin", "Alpha", "Beta", "Chi", "Epsilon", "Eta", "Iota",
            "Kappa", "Mu", "Nu", "Omicron", "Rho", "Tau", "Zeta", "darr", "uarr", "larr", "rarr", "harr",
            "lrarr", "dArr", "Darr", "uArr", "Uarr", "lArr", "Larr", "rArr", "Rarr", "hArr", "Harr", "lrArr",
            "Lrarr", "clubs", "diamonds", "hearts", "spades", "cnums", "Complex", "natnums", "real", "reals",
            "Reals", "plusmn", "exist", "isin", "sub", "sube", "supe", "sdot", "sect", "yen", "checkmark",
            "circledR", "copyright", "maltese", "minuso", "circ", "thetasym", "weierp", "Dagger", "image", "varPi"
        ]
    }

    private static func normalize(name: String): String {
        if (name.size > 0 && name[0] == b'\\') {
            return name[1..name.size]
        }
        return name
    }
}

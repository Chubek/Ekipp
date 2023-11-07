# Ekipp: A Macro Preprocessor Language

Ekipp is a macro preprocessor similar to m4, m5.awk, and GPP. Any text not prefixed with one of the 3 preset (and unchangable) 'prefix tokens' is bypassed and printed into the output. But if a text is prefixed, you can:

1- Call one of the many built-in macros.

2- Evaluate an expression.

3- Define and call a macro, with or without arguments.

## Installation

You can easily install Ekipp using the following command (on POSIX/UNIX systems, use WSL2 or CygWin on Windows NT):

```
wget -qO- https://raw.githubusercontent.com/Chubek/Ekipp/master/install.sh | sudo sh
```

After installation, type in `man 1 ekipp` to view the manual.

You need the following libraries on your system:

LibGC, LibUniString, LibLex, GNU LibReadLine

You can easily install all these libraries from your system's package manager (for example, apt).

## Example

Examples for Ekipp reside in `EXAMPLES` directory, there are several examples in the manual as well. Some examples:


### Defining a Macro and Calling It

```
@! define $ mymacro123 => ''bar #0 #1''

$! mymacro123 ( foo, bar )

```

This will print `bar foo bar`.

### Evaluatng Expressions

```
#! eval $ 1+1

```

This will print `2` (note: there must be a newline at the end of each macro sequence).


### Executing a Command

```
#! exec $ ''echo 123''

```

This command will be piped.

As stated above, more examples in the directory and the man page.


## Contribution

All contributions are welcome! Send me your pull request.

## Contact

chubakbidpaa@gmail.com
chubakbidpaa@riseup.net
chubakbidpaa@outlook.com

Discord: `.chubak`

Telegram: `@rapturemaster`











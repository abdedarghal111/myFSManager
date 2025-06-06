#!/bin/fish

# obtener el path relativo al script
set REL_ROOT_DIR (dirname (status --current-filename))

# obtener el path absoluto al script
set ABS_ROOT_DIR (
    set relativePath $REL_ROOT_DIR
    set currentPath (pwd)
    cd $relativePath
    set absolutePath (pwd)
    cd $currentPath
    echo $absolutePath
)

set VENV_DIR $ABS_ROOT_DIR/.venv

function pip
    if test -d $VENV_DIR
        "$VENV_DIR/bin/pip" $argv
    else
        echo "Instala las dependencias con --init"
        exit 1
    end
end

function python
    if test -d $VENV_DIR
        "$VENV_DIR/bin/python" $argv
    else
        echo "Instala las dependencias con --init"
        exit 1
    end
end


switch $argv[1]
    case "--init"
        command python -m venv $VENV_DIR

        #cp $ABS_ROOT_DIR/.env.example $ABS_ROOT_DIR/.env

        python -m pip install --upgrade pip
        pip install -r requirements.txt

        echo "Dependencias instaladas."

    case "--update"
        python -m pip install --upgrade pip
        pip install -r requirements.txt

        echo "Dependencias actualizadas."

    case "--install"
        python -m pip install --upgrade pip
        pip install -r requirements.txt
    
    case "--run"

        python $ABS_ROOT_DIR/$argv[2]

    case "--remove"
        rm -rf $VENV_DIR
end
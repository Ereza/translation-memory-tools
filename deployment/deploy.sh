#!/bin/bash

copy_files() {

    #Softcatalà headers and footers
    rm -r -f $2/ssi
    mkdir -p $2/ssi
    cp -r $1/web-2015/ssi/* $2/ssi

    # Index
    rm -r -f $2/indexdir
    mkdir -p $2/indexdir
    cp -r $1/tm-git/src/web/indexdir/* $2/indexdir

    # Search TM app
    mkdir -p $2/css
    mkdir -p $2/img
    mkdir -p $2/templates
    mkdir -p $2/models
    mkdir -p $2/chosen

    cp $1/tm-git/src/web/css/recursos.css $2/css
    cp $1/tm-git/src/web/index.html $2
    cp $1/tm-git/src/web/web_search.py $2
    cp $1/tm-git/src/web/footer.html $2
    cp $1/tm-git/src/statistics.html $2
    cp $1/tm-git/src/select-projects.html $2
    cp $1/tm-git/src/web/robots.txt $2
    cp $1/tm-git/src/web/memories.html $2
    cp $1/tm-git/src/web/terminologia.html $2
    cp $1/tm-git/src/web/llistats_iso.html $2
    cp $1/tm-git/src/web/img/*.png $2/img
    cp $1/tm-git/src/web/templates/*.html $2/templates
    cp $1/tm-git/src/web/models/*.py $2/models
    cp $1/tm-git/src/terminology/glossarysql.py $2/models
    cp -r $1/tm-git/src/web/chosen/* $2/chosen

    # Web dependencies
    rm -r -f $2/builder
    mkdir $2/builder
    cp $1/tm-git/src/builder/cleanupfilter.py $2/builder
    cp $1/tm-git/src/builder/projectmetadatadao.py $2/builder
    cp $1/tm-git/src/builder/projectmetadatadto.py $2/builder

    # Download memories
    cp $1/tm-git/src/projects.json $2
    cp $1/tm-git/src/download.html $2
    rm -r -f $2/memories
    mkdir $2/memories
    cp $1/tm-git/src/memories/*.zip $2/memories

    # Deploy terminology
    cd $1/tm-git/src/
    cp *.html $2
    cp *.csv $2
    cp sc-glossary.db3 $2/glossary.db3
    cp statistics.db3 $2/statistics.db3

    # Deploy quality reports
    cd $1/tm-git/src/output/quality
    mkdir -p $2/quality
    cp *.html $2/quality

    # ISO lists
    cp $1/tm-git/src/isolists/*.html $2

    # Log
    rm -r -f $2/logs
    mkdir $2/logs
    cp $1/tm-git/src/*.log $2/logs
}

restart_appserver() {
    exists='which supervisorctl&>/dev/null'
    if ! $exists ; then
        return
    fi

    sudo supervisorctl stop recursos_preprod
    sudo supervisorctl stop recursos_dev
    sudo supervisorctl stop recursos
    sudo supervisorctl start recursos_preprod
    sudo supervisorctl start recursos_dev
    sudo supervisorctl start recursos
}


if [ "$#" -ne 4 ] ; then
    echo "Usage: deploy.sh ROOT_DIRECTORY_OF_BUILD_LOCATION TARGET_DESTINATION TARGET_PREPROD PUBLIC_DATA"
    echo "Invalid number of parameters"
    exit
fi  

ROOT="$1"
TARGET_DIR="$2"
TARGET_PREPROD="$3"
PUBLIC="$4"

# Run unit tests
cd $ROOT/tm-git/
nosetests
RETVAL=$?
if [ $RETVAL -ne 0 ]; then
    echo "Aborting deployment. Unit tests did not pass"
    exit
fi

if [ -n "${TARGET_PREPROD}" ]; then
    # Deploy to a pre-production environment where we can run integration tests
    copy_files $ROOT $TARGET_PREPROD
    restart_appserver

    # Run integration tests
    cd $ROOT/tm-git/integration-tests/
    python run.py -e preprod

    RETVAL=$?
    if [ $RETVAL -ne 0 ]; then
        echo "Aborting deployment. Integration tests did not pass"
        cat $ROOT/tm-git/src/builder-error.log
        exit
    fi
fi

# Deployment to production environment
copy_files $ROOT $TARGET_DIR
restart_appserver

# Notify completion
INTERMEDIATE_PO=$PUBLIC/translation-memories/po
BACKUP_DIR=$PUBLIC/previous
cd $ROOT/tm-git/src
python compare_sets.py -s  $BACKUP_DIR -t $INTERMEDIATE_PO
ls -h -s -S  $TARGET_DIR/quality/*.html
cat builder-error.log

echo "Deployment completed $ROOT $TARGET_DIR"

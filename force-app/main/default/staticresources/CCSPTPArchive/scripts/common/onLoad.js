var sfLoad_ = (function() {

    var appendScript = function(scripts, parentTagName) {
        if (!scripts || !scripts.length)
            console.log('No scripts to render.');

        for (var i = 0; i <= scripts.length - 1; i++) {

            var script = document.createElement('script');
            script.type = 'text/javascript';
            script.src = scripts[i];
            script.async = false;

            document.getElementsByTagName(parentTagName)[0].appendChild(script);
            console.log('Script ' + scripts[i] + ' was appended to ' + parentTagName);
        }
    };

    var appendCss = function(styles, parentTagName) {
        if (!styles || !styles.length)
            console.log('No styles to render.');

        for (var i = 0; i <= styles.length - 1; i++) {

            var link = document.createElement('link');
            link.setAttribute('rel', 'stylesheet');
            link.setAttribute('type', 'text/css');
            link.setAttribute('href', styles[i]);

            document.getElementsByTagName(parentTagName)[0].appendChild(link);
            console.log('Style ' + styles[i] + ' was appended to ' + parentTagName);
        }
    };

    var renderImages = function() {
        while (document.getElementsByTagName('apex:image').length) {
            try {
                var apexImage = document.getElementsByTagName('apex:image')[0];

                var img = document.createElement('img');
                img.id = apexImage.id;
                img.alt = apexImage.getAttribute('alt');
                img.class = apexImage.getAttribute('styleclass');
                var imageSrc = (apexImage.getAttribute('value') || apexImage.getAttribute('url')).split(',')[1];
                if (imageSrc) {
                    img.src = Archive_path + imageSrc.slice(0, -2).replace(/\'/g, '');
                }

                apexImage.parentNode.insertBefore(img, apexImage);
                apexImage.remove();
                console.log('Changed apexImage to ' + img.outerHTML);
            } catch (e) {
                console.log('Error occured while trying to work on ' + apexImages[i].outerHTML + ' \nerror is: ' + e);
            }
        }
    }

    var isRunningLocally = function() { return Archive_path.includes('JSENCODE'); }
    var isLightning = function() { return window.location.href.includes('mode=Lightning'); }

    var onLoad = function() {
        isRunningLocally = isRunningLocally();
        isLightning = isLightning();

        if (!sfLoad_appendOnLoad) {
            console.log('Please define sfLoad_appendOnLoad');
            return;
        }

        if (isRunningLocally) // we are running locally
        {
            Archive_path = '';

            document.addEventListener('DOMContentLoaded', function() {
                renderImages();
            }, false);
        }

        for (var i = 0; i <= sfLoad_appendOnLoad.length - 1; i++) {
            try {
                var item = sfLoad_appendOnLoad[i];

                if (item.isCommon) {
                    //do nothing
                } else if (item.isLightning && !isLightning) {
                    continue;
                } else if (item.isClassic && isLightning) {
                    continue;
                } else if (item.isLocal && !isRunningLocally) {
                    continue;
                }

                var files = item.files.slice();

                if (item.shouldAppendArchivePath) {
                    files = files.map(function(a) { return Archive_path + (isRunningLocally ? '' : '/') + a; });
                }

                if (item.type === 'script')
                    appendScript(files, item.appendToTag);
                else if (item.type === 'css')
                    appendCss(files, item.appendToTag);
                else
                    new Error('Type ' + item.type + ' is not supported! ');



            } catch (e) {
                console.log('Error occured while trying to work on ' + JSON.stringify(sfLoad_appendOnLoad[i]) + ' \nerror is: ' + e);
            }
        }
    };

    return {
        appendCss: appendCss,
        appendScript: appendScript,
        isRunningLocally: isRunningLocally(),
        isLightning: isLightning(),
        onLoad: onLoad,
        renderImages: renderImages
    };


}());

sfLoad_.onLoad();
---
layout: docs
title: Your First Application with MITHgrid
---
# Your First Application with MITHgrid

* auto-gen TOC:
{:toc}


## Basics
MITHgrid is being actively developed by the umd-mith team. To maximize the benefits you derive out of this framework please look at these basic concepts critical to MITHgrid. **[highly recommended]**
* [Namespacing in MITHgrid](http://umd-mith.github.io/mithgrid/docs/core/#namespace_management)
* [DataStore](http://umd-mith.github.io/mithgrid/docs/data-stores/)
* [Presentations](http://umd-mith.github.io/mithgrid/docs/presentations/) and [Controllers](http://umd-mith.github.io/mithgrid/docs/controllers/)


Once we have the basics in place, we can quickly develop and deploy MITHgrid applications. 
MITHgrid creates a in-memory graph database at its core. This is an modern approach in building single-page web apps which has connected data. Everything in MITHgrid world is done through events. There is an inherent binding between the model and UI. With little bit of configuration in presentation code, we can make it 2-way binding.

##Installation
To begin with, lets install MITHgrid in our working directory.

### Using Git

MITHgrid is written in coffeeScript because of its elegance and readability over javascript.
To get the latest copy of MITHgrid code , clone the git code into your machine. 
```
git clone https://github.com/umd-mith/mithgrid.git
```
Run MAKE on your terminal when inside the source folder.
```
MAKE
```
This will create a dist/ folder which contains the compiled javascript code (Mithgrid.js file). [**More details**](https://github.com/selvam1991/mithgrid/blob/gh-pages/docs/downloading.md#build-from-git)


### Using Bower
Once you have installed [bower](http://bower.io), you can run this command on terminal when inside your working folder.
```
bower install mithgrid
```
This will create a folder bower_components/ containing the mithgrid code.

### Using Yeoman
To skip all this and directly install the working application, follow the steps at https://github.com/selvam1991/generator-mithgrid


##App Code

As you would have noted, everything inside MITHgrid world is a namespace, including its guts. So to create a new application, we namespace it under Application.
 We will namespace all the app code into "MITHgrid.Application.FirstApp" namespace.  

```coffeescript
MITHgrid.Application.namespace "test", function(test)->
```

The callback function passed takes just 1 parameter. i.e. the newly created namespace object.  A new object FirstApp is created under the Application namespace, which the callback function is called with.

The method `initInstance` is our entry point which sets up the instance . This method will be exposed along with any other optional method you feel like exposing .
```coffeescript
MITHgrid.Application.namespace 'test', (test)->
  test.initInstance = (args...)->
    # app code
```
initInstance takes configurational arguments to start the app (the instance of FirstApp). For example, the DOM element to act as the root element for the application. This way we can have many instances of application bound to different DOM elements running in the same page.

```coffeescript
MITHgrid.Application.namespace 'test', (test)->
  test.initInstance = (args...)->
    MITHgrid.Application.initInstance 'MITHgrid.Application.test', args... , (that,container)->
     that.ready ->
       #code goes here
```

All the code that is present inside the anonymous function that is passed in that.ready function gets executed on app.run() call.


### Initializing Presentations
Now that the bootstrap app code is in place, we can go ahead and place responsive view elements ( called presentation). Presentations are hard wired to the backend model while initialisation.
In this example, we are going to place 2 tables and 2 simple text presentations. 
```coffeescript
that.ready ->
 
        MITHgrid.Presentation.Table.initInstance '#students',
          dataView:that.dataView.students
          columns:['name','math','science','english']
          columnLabels:
            name:'Name'
            math:'Math'
            english:'English'
            science:'Science'

```

Since each presentation is decoupled and configurable, the config object which we pass decides critical options such as which model to bind with.

*Lens* : This an very useful feature inherited by every presentation.  We will deal with this in the next tutorial.

```coffeescript
  # lens function used to parse(for presentation) every item in the dataview
    _lens = (c,v,m,i)->
      v = $(c).data('count') + 1
      $(c).html(v).data('count',v)


    MITHgrid.Presentation.SimpleText.initInstance '#totalStudents',
      dataView:that.dataView.students
      lenses:
        'student': _lens

```

*A final word on the flow of the application* : Communication inside MITHgrid happens using events. Any change in the model (dataStore) triggers events .While a presentation or controller is initiated , it subscribes to these events thus making it responsive.

The complete code is present [**here**](https://gist.github.com/selvam1991/6702818)

The application demo is [**here**](mithgrid-selvam.rhcloud.com/basic)






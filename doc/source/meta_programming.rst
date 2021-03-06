.. _meta_programming:

Meta programming
================

Trigger functionalities can be extended with Meta programming. It is possible to customize the following:

- :ref:`Events <events>`
- :ref:`Functions <functions>`
- :ref:`Actions <actions>`
- :ref:`Data types <data_types>`

Meta-model file format:

.. code-block:: lua

    return {
        dataTypes = ..., -- table (or Lua function that returns a table) consisting of action types
        events = ..., -- table (or Lua function that returns a table) consisting of action types
        actions = ..., -- table (or Lua function that returns a table) consisting of action types
        functions = ..., -- table (or Lua function that returns a table) consisting of function types
    }

.. _events:

Events
------

Events invoke triggers, and are caused by various Spring callins.

They have the following fields:

- **humanName** (mandatory). Human readable name for display in the UI.
- **name** (mandatory). Unique identifier that is used to produce readable models.
- **param** (optional). Additional, event data sources that are available to the entire trigger.
- **tags** (optional). List of human-readable tags used for grouping in the UI.


Example of event programming:

.. code-block:: lua

    {
        humanName = "Unit enters area",
        name = "UNIT_ENTER_AREA",
        param = { "unit", "area" },
    }

.. _actions:

Actions
-------

.. _meta_hello_world:
.. code-block:: lua

    {
        humanName = "Hello world",
        name = "MY_HELLO_WORLD",
        execute = function()
            Spring.Echo("Hello world")
        end,
    }

The :ref:`above <meta_hello_world>` code block defines a simple action. The *name* and *humanName* properties of the action define the machine (unique) and display name respectively. The *execute* property defines the function to be executed when the trigger is successfully fired. When used in the editor, this action would print a *Hello World* on the screen.

It is common for actions to receive *input* that defines its behavior. One such example would be:

.. code-block:: lua

    {
        humanName = "Print unit position",
        name = "PRINT_UNIT_POSITION",
        input = "unit",
        execute = function(input)
            local x, y, z = Spring.GetUnitPosition(input.unit)
            Spring.Echo("Unit position: ", x, y, z)
        end,
    }

As one might guess, this action would take the specified *unit* as *input* and print out its position. The GUI editor will parse the input type and the user (level designer) will be able to specify the unit when creating an instance of this action. This is equivalent to the following Lua code:

.. code-block:: lua

    function PRINT_UNIT_POSITION(unitID)
        local x, y, z = Spring.GetUnitPosition(unitID)
        Spring.Echo("Unit position: ", x, y, z)
    end


.. _functions:

Functions
---------

The real power of the meta programming comes with the introduction of function types. Function types produce an output (result of the function), which often depends on the input.

.. note:: There's a difference between a *Lua* function and a function type in the *meta model*. The *function type* represents a component in the meta model and is defined with a table.

.. note:: Function types should not have a side effect (they shouldn't cause any changes to the game state), but they don't have to be pure (they don't need to produce the same output for the same input).

Example of a function type:

.. code-block:: lua

    {
        humanName = "Unit Health",
        name = "UNIT_HEALTH",
        input = "unit",
        output = "number"
        execute = function(input)
            return Spring.GetUnitHealth(input.unit)
        end,
    }

This function type takes a *unit* as *input* and produce a *number* as *output*. A special class of these function types are those that return *bool* as *output*, and they represent *conditions* in the GUI programming.

.. _data_types:

Data types
----------

Custom data types can be created as composites of builtin data types. This allows game developers to expose game-specific concepts.
These data types are defined by specifying three fields: *humanName* (display name), *name* (machine name) and *input* (table of fields that it consists of).
Example of a *Person* data type:

.. code-block:: lua

    {
        humanName = "Person",
        name = "person",
        input = {
            {
                name = "first_name",
                humanName = "First name",
                type = "string",
            },
            {
                name = "last_name",
                humanName = "Last name",
                type = "string",
            }
        }
    }

This custom data type can then be used in meta-programming as usual. Below we present a sample action that would print out person's details.

.. code-block:: lua

    {
        humanName = "Print person",
        name = "PRINT_PERSON",
        input = "person" ,
        execute = function(input)
            local person = input.person
            Spring.Echo("Hello! I am " .. person.first_name .. " " .. person.last_name)
        end
    }

Higher-order functions (Advanced)
---------------------------------

As one of the more advanced uses meta-programming also has support for higher-order functions, i.e. fuctions that take other functions as parameters. An example of a *filter* higher-order function implemented in Lua is given below. This function will filter out table elements that don't satisfy a given function. In this case, it will filter out elements that are lower or equal to five. As functions as first-class citizens in Lua, writing them is relatively simple.

.. code-block:: lua

    function above5(x)
    	return x > 5
    end

    function filter(elements, f)
    	local retVal = {}
    	for _, el in pairs(elements) do
    		if f(el) then
    			table.insert(retVal, el)
    		end
    	end
    	return retVal
    end

    elements = {1, 12, 3, -5, 7}
    filter(elements, above5)

In SpringBoard's meta-programming however, higher-order functions need to have explicit types, as the meta-programming language is statically (and explicitly) typed. The same filter function type is given below, now in SpringBoard's meta-programming language. The *extraSources* parameter defines additional scoped inputs. The function signature is defined by the *output* parameter. Normally the *input* parameter could also be specified, but that wasn't done in this case, as the predicate function isn't *required* to use the *number* parameter.

.. code-block:: lua

    {
        humanName = "Filter elements in number array",
        name = "number_array_FILTER",
        input = {
            "number_array",
            {
                name = "filter_function",
                type = "function",
                extraSources = {
                    "number",
                },
                output = "bool",
            },
        },
        output = "number_array",
        tags = {"Array"},
        execute = function(input)
            local retVal = {}
            for _, element in pairs(input.number_array) do
                if input.filter_function({number = element}) then
                    table.insert(retVal, element)
                end
            end
            return retVal
        end,
    }

Additionally, it is possible to use actions as parameters to higher-order actions types, in the same way like it is done for functions. Below we present a *foreach* action type that will iterate through all elements of an array and execute the specified action for them.

.. code-block:: lua

    {
        humanName = "For each number in number array",
        name = "number_array_FOR_EACH",
        input = {
            "number_array",
            {
                name = "for_each_action",
                type = "action",
                extraSources = {
                    "number",
                },
            },
        },
        tags = {"Array"},
        execute = function(input)
            for _, element in pairs(input.number_array) do
                input.for_each_action({number = element})
            end
        end,
    }

Example
-------

An example of practical meta-programming usage can be seen in the case of `Gravitas <https://github.com/SpringCabal/SpringBoard-Gravitas/blob/master/triggers/gravitas_triggers.lua>`_.

In particular we will focus on two parts of it: the *GATE_OPENED* event type and the *LINK_PLATE_GATE* action type.

The event type is straightfoward, and signals a gate being opened. The unit parameter represents the gate being opened.

.. code-block:: lua

    {
        humanName = "Gate opened",
        name = "GATE_OPENED",
        param = "unit",
    }

The *LINK_PLATE_GATE* action type takes two unit parameters, one representing a plate, and other representing a gate. It then uses game API to link the two together, causing the gate to open if the pressure plate is activated.

.. code-block:: lua

    {
        humanName = "Link Plate To Gate",
        name = "LINK_PLATE_GATE",
        input = {
            {
                name = "plate",
                type = "unit",
            },
            {
                name = "gate",
                type = "unit",
            },
        },
        execute = function(input)
            GG.Plate.SimpleLink(input.plate, input.gate)
        end
    }

Example scenario implemented using this custom meta-programming is available at `Gravitas Example <https://drive.google.com/file/d/0B9FQjbVMFgL2dmFsWmpCUVl5R0U/view?usp=sharing>`_.
To use it, extract it and open it as a SpringBoard project.

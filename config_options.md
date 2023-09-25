<h1 class="code-line" data-line-start=0 data-line-end=1 ><a id="MusicBox_Configuration_Options_0"></a>MusicBox Configuration Options</h1>
<p class="has-line-data" data-line-start="2" data-line-end="3">Configuration for the MusicBox model is written in a JSON file passed to the model at runtime. This config file also points the model to any additional input files supplied by the user, and allows configuration for these files.</p>
<p class="has-line-data" data-line-start="4" data-line-end="5">config.json contains four main sections, each specifying different parts of the MusicBox configuration.</p>
<h5 class="code-line" data-line-start=5 data-line-end=6 ><a id="MusicBox_configuration_file_sections_5"></a>MusicBox configuration file sections:</h5>
<ul>
<li class="has-line-data" data-line-start="6" data-line-end="7"><strong>Box model options</strong>- Basic model settings.</li>
<li class="has-line-data" data-line-start="7" data-line-end="8"><strong>Initial conditions</strong>- Configuration for inital enviornmental conditions.</li>
<li class="has-line-data" data-line-start="8" data-line-end="9"><strong>Evolving conditions</strong>- Configuration for conditions changing over time.</li>
<li class="has-line-data" data-line-start="9" data-line-end="11"><strong>Model components</strong>- Settings for the chemical solver.</li>
</ul>
<h5 class="code-line" data-line-start=11 data-line-end=12 ><a id="Base_structure_for_configjson_11"></a>Base structure for config.json:</h5>
<pre><code class="has-line-data" data-line-start="13" data-line-end="20" class="language-json">{
    "<span class="hljs-attribute">box model options</span>": <span class="hljs-value">{}</span>,
    "<span class="hljs-attribute">initial conditions</span>": <span class="hljs-value">{}</span>,
    "<span class="hljs-attribute">evolving conditions</span>": <span class="hljs-value">{}</span>,
    "<span class="hljs-attribute">model components</span>": <span class="hljs-value">{}
</span>}
</code></pre>
<hr>
<h3 class="code-line" data-line-start=23 data-line-end=24 ><a id="Box_Model_Options_23"></a>Box Model Options</h3>
<p class="has-line-data" data-line-start="25" data-line-end="26">Box model options configure the basic settings for the box model run, including grid options and time step lengths.</p>
<dl>
<dt>grid</dt>
<dd>string, required</dd>
<dd>Grid type for model run. “box” is the only currently supported grid.</dd>
<dt>chemistry time step [units]</dt>
<dd>float/int, required</dd>
<dd>Time unit options: <code>&quot;sec&quot;</code>, <code>&quot;min&quot;</code>, <code>&quot;hour&quot;</code>, <code>&quot;day&quot;</code></dd>
<dt>output time step [units]</dt>
<dd>float/int, required</dd>
<dd>Time unit options: <code>&quot;sec&quot;</code>, <code>&quot;min&quot;</code>, <code>&quot;hour&quot;</code>, <code>&quot;day&quot;</code></dd>
<dt>simulation length [units]</dt>
<dd>float/int, required</dd>
<dd>Time unit options: <code>&quot;sec&quot;</code>, <code>&quot;min&quot;</code>, <code>&quot;hour&quot;</code>, <code>&quot;day&quot;</code></dd>
<dt>simulation start</dt>
<dd>specified as JSON object:<br>
<code>{ &quot;time zone&quot; : &quot;UTC-8&quot;, &quot;year&quot; : 2020, &quot;month&quot; : 6, &quot;day&quot; : 10, &quot;hour&quot; : 13 }</code></dd>
</dl>
<p class="has-line-data" data-line-start="54" data-line-end="55"><strong>Example box model options configuration:</strong></p>
<pre><code class="has-line-data" data-line-start="56" data-line-end="72" class="language-json">{
  "<span class="hljs-attribute">box model options</span>" : <span class="hljs-value">{
    "<span class="hljs-attribute">grid</span>"                      : <span class="hljs-value"><span class="hljs-string">"box"</span></span>,
    "<span class="hljs-attribute">chemistry time step [min]</span>" : <span class="hljs-value"><span class="hljs-number">5.0</span></span>,
    "<span class="hljs-attribute">output time step [hr]</span>"     : <span class="hljs-value"><span class="hljs-number">1.0</span></span>,
    "<span class="hljs-attribute">simulation length [hr]</span>"    : <span class="hljs-value"><span class="hljs-number">2.5</span></span>,
    "<span class="hljs-attribute">simulation start</span>" : <span class="hljs-value">{
      "<span class="hljs-attribute">time zone</span>" : <span class="hljs-value"><span class="hljs-string">"UTC-8"</span></span>,
      "<span class="hljs-attribute">year</span>" : <span class="hljs-value"><span class="hljs-number">2020</span></span>,
      "<span class="hljs-attribute">month</span>" : <span class="hljs-value"><span class="hljs-number">6</span></span>,
      "<span class="hljs-attribute">day</span>" : <span class="hljs-value"><span class="hljs-number">10</span></span>,
      "<span class="hljs-attribute">hour</span>" : <span class="hljs-value"><span class="hljs-number">13</span>
    </span>}
  </span>}
</span>}
</code></pre>
<h3 class="code-line" data-line-start=73 data-line-end=74 ><a id="Initial_Conditions_73"></a>Initial Conditions</h3>
<p class="has-line-data" data-line-start="75" data-line-end="76">Initial environmental conditions, concentrations for chemical species, and reaction rates/rate constants that have a MUSICA name can be set here. <strong>The conditions you set here will remain at the value you specify until updated by the solver (as is the case for chemical species concentrations) or overwritten by evolving conditions</strong>.</p>
<dl>
<dt>input data files</dt>
<dd>For use of initial conditions data files, the file name is included as a key within the <code>&quot;initial conditions&quot;</code> JSON object.<br>
<code>&quot;initial conditions&quot;: {fileName: {}}</code></dd>
<dd>
<dl>
<dt>file options:</dt>
<dd>
<dl>
<dt>delimiter</dt>
<dd>MusicBox will use <code>,</code> as a default delimiter. A custom delimiter can be specified.</dd>
<dd><code>fileName: {&quot;delimiter&quot;: &quot;&amp;&quot;}</code></dd>
</dl>
</dd>
<dd>
<dl>
<dt>properties</dt>
<dd>Properties for data colunmns within a conditions file can be specified with the <code>properties</code> key. Individual columns are specified with the column name from the data file, and all columns can be specified with the <code>*</code> key.</dd>
<dd>Properties are specified with this general format:<br>
<code>fileName: {&quot;properties&quot;: {PREFIX.PropertyName: {property: value}}</code></dd>
<dd><strong>Changing units:</strong></dd>
<dd>Units are changed by specifying the desired data column title and the desired units:<br>
<code>fileName: {&quot;properties&quot;: {&quot;ENV.pressure&quot;: {&quot;units&quot;: &quot;kPa&quot;}}}</code></dd>
<dd><strong>Shifting time data:</strong></dd>
<dd>Time data for evolving conditions files can be shifted to a specified time value.</dd>
<dd><code>&quot;properties&quot; : { &quot;time.hr&quot; : { &quot;shift first entry to&quot; :{ &quot;time zone&quot; : &quot;UTC-8&quot;, &quot;year&quot; : 2020, &quot;month&quot; : 6, &quot;day&quot; : 10, &quot;hour&quot; : 13 } } }</code></dd>
<dd><strong>Renaming columns:</strong></dd>
<dd>Column names can be changed by specifying the MusicBox name.</dd>
<dd><code>&quot;properties&quot; : { &quot;*&quot; : { &quot;MusicBox name&quot; : &quot;PHOT.*&quot; }}</code></dd>
</dl>
</dd>
</dl>
</dd>
</dl>
<h4 class="code-line" data-line-start=109 data-line-end=110 ><a id="Input_file_formatting_109"></a>Input file formatting:</h4>
<p class="has-line-data" data-line-start="110" data-line-end="111"><strong>Initial conditions input files should be comma-separated text files with variable names on the first line, followed by a single line of data describing the initial value for each variable.</strong> Variable names that are not recognized by MusicBox will be ignored.</p>
<p class="has-line-data" data-line-start="112" data-line-end="114">Variable names should be structured as follows:<br>
<code>PREFIX.PropertyName</code></p>
<p class="has-line-data" data-line-start="115" data-line-end="116">The <code>PREFIX</code> indicates what type of property is being set. The property types corresponding to each recognized prefix are described below. The Property Name is the name of the property in the mechanism.</p>
<table class="table table-striped table-bordered">
<thead>
<tr>
<th style="text-align:center">Prefix</th>
<th>Property Type</th>
<th>Use</th>
<th>Default Unit</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:center"><code>CONC</code></td>
<td>Chemical species concentrations</td>
<td>Used with chemical species specified in the chemical mechanism</td>
<td>mol/m^3</td>
</tr>
<tr>
<td style="text-align:center"><code>ENV</code></td>
<td>Enviornmental conditions</td>
<td>Used to specify temperature and pressure</td>
<td>K or Pa</td>
</tr>
<tr>
<td style="text-align:center"><code>EMIS</code></td>
<td>Emission of a chemical species</td>
<td>Used to specify the rate constant for an emission reaction specified in the chemical mechansim</td>
<td>mol m-3 s-1</td>
</tr>
<tr>
<td style="text-align:center"><code>LOSS</code></td>
<td>First-order loss of a chemical species</td>
<td>Used to specify the rate constant for an loss reaction specified in the chemical mechansim</td>
<td>s-1</td>
</tr>
<tr>
<td style="text-align:center"><code>PHOT</code></td>
<td>Photolysis of a chemical species</td>
<td>Used to specify the rate constant for a photolysis reaction specified in the chemical mechansim</td>
<td>s-1</td>
</tr>
</tbody>
</table>
<hr>
<dl>
<dt>chemical species</dt>
<dd>Without an initial conditions file, inital concentrations of chemical species can be set directly inside the JSON file. Species specifed in the configuration must also be present in the chemical mechanism.</dd>
</dl>
<pre><code class="has-line-data" data-line-start="129" data-line-end="135" class="language-json">{"<span class="hljs-attribute">chemical species</span>": <span class="hljs-value">{
    "<span class="hljs-attribute">Ar</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">0.0334</span></span>}</span>,
    "<span class="hljs-attribute">CO2</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">0.00146</span></span>}
    </span>}
</span>}
</code></pre>
<hr>
<dl>
<dt>enviornmental conditions</dt>
<dd>Without an initial conditions file, inital concentrations of chemical species can also be set directly inside the JSON file.</dd>
</dl>
<pre><code class="has-line-data" data-line-start="139" data-line-end="145" class="language-json">{"<span class="hljs-attribute">enviornmental conditions</span>": <span class="hljs-value">{
    "<span class="hljs-attribute">Temperature</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [K]</span>": <span class="hljs-value"><span class="hljs-number">206</span></span>}</span>,
    "<span class="hljs-attribute">Pressure</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [Pa]</span>": <span class="hljs-value"><span class="hljs-number">6150</span></span>}
    </span>}
</span>}
</code></pre>
<hr>
<p class="has-line-data" data-line-start="146" data-line-end="147"><strong>Example initial conditions configuration with an input file and specifed delimiter:</strong></p>
<pre><code class="has-line-data" data-line-start="148" data-line-end="159" class="language-json">{
  "<span class="hljs-attribute">initial conditions</span>" : <span class="hljs-value">{
    "<span class="hljs-attribute">initial_conditions_data.csv</span>": <span class="hljs-value">{
        "<span class="hljs-attribute">delimiter</span>": <span class="hljs-value"><span class="hljs-string">"&amp;"</span></span>,
        "<span class="hljs-attribute">properties</span>": <span class="hljs-value">{
            "<span class="hljs-attribute">ENV.pressure</span>": <span class="hljs-value">{"<span class="hljs-attribute">units</span>": <span class="hljs-value"><span class="hljs-string">"kPa"</span></span>}
        </span>}
    </span>}
  </span>}
</span>}
</code></pre>
<p class="has-line-data" data-line-start="159" data-line-end="160"><strong>Example initial conditions configuration specifying chemical species and enviornmental conditions:</strong></p>
<pre><code class="has-line-data" data-line-start="161" data-line-end="176" class="language-json">{
    "<span class="hljs-attribute">chemical species</span>": <span class="hljs-value">{
        "<span class="hljs-attribute">Ar</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">0.0334</span></span>}</span>,
        "<span class="hljs-attribute">CO2</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">0.00146</span></span>}</span>,
        "<span class="hljs-attribute">H2O</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">1.19e-05</span></span>}</span>,
        "<span class="hljs-attribute">N2</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">2.8</span></span>}</span>,
        "<span class="hljs-attribute">O2</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">0.75</span></span>}</span>,
        "<span class="hljs-attribute">O3</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">8.1e-06</span></span>}
    </span>}</span>,
    "<span class="hljs-attribute">environmental conditions</span>": <span class="hljs-value">{
        "<span class="hljs-attribute">temperature</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [K]</span>": <span class="hljs-value"><span class="hljs-number">206.6374207</span></span>}</span>,
        "<span class="hljs-attribute">pressure</span>": <span class="hljs-value">{"<span class="hljs-attribute">initial value [Pa]</span>": <span class="hljs-value"><span class="hljs-number">6152.049805</span></span>}
    </span>}
</span>}
</code></pre>
<hr>
<h3 class="code-line" data-line-start=177 data-line-end=178 ><a id="Evolving_Conditions_177"></a>Evolving Conditions</h3>
<p class="has-line-data" data-line-start="178" data-line-end="179"><strong>Evolving conditions files contain model conditions that change during the simulation.</strong> These can be environmental conditions, chemical species concentrations, or rates/rate constants for reactions with a MUSICA name. <strong>Evolving conditions take precedence over initial conditions.</strong></p>
<dl>
<dt>input data files</dt>
<dd>For use of initial conditions data files, the file name is included as a key within the ‘evolving conditions’ JSON object.<br>
<code>&quot;evolving conditions&quot;: {fileName: {}}</code></dd>
<dd>
<dl>
<dt>file options:</dt>
<dd>
<dl>
<dt>delimiter</dt>
<dd>MusicBox will use <code>,</code> as a default delimiter. A custom delimiter can be specified.</dd>
<dd><code>fileName: {&quot;delimiter&quot;: &quot;&amp;&quot;}</code></dd>
</dl>
</dd>
<dd>
<dl>
<dt>properties</dt>
<dd>Properties for data colunmns within a conditions file can be specified with the <code>properties</code> key. Individual columns are specified with the column name from the data file, and all columns can be specified with the <code>*</code> key.</dd>
<dd>Properties are specified with this general format:<br>
<code>fileName: {&quot;properties&quot;: {PREFIX.PropertyName: {property: value}}</code></dd>
<dd><strong>Changing units:</strong></dd>
<dd>Units are changed by specifying the desired data column title and the desired units:<br>
<code>fileName: {&quot;properties&quot;: {&quot;ENV.pressure&quot;: {&quot;units&quot;: &quot;kPa&quot;}}}</code></dd>
<dd><strong>Shifting time data:</strong></dd>
<dd>Time data for evolving conditions files can be shifted to a specified time value.</dd>
<dd><code>&quot;properties&quot; : { &quot;time.hr&quot; : { &quot;shift first entry to&quot; :{ &quot;time zone&quot; : &quot;UTC-8&quot;, &quot;year&quot; : 2020, &quot;month&quot; : 6, &quot;day&quot; : 10, &quot;hour&quot; : 13 } } }</code></dd>
<dd><strong>Renaming columns:</strong></dd>
<dd>Column names can be changed by specifying the MusicBox name.</dd>
<dd><code>&quot;properties&quot; : { &quot;*&quot; : { &quot;MusicBox name&quot; : &quot;PHOT.*&quot; }}</code></dd>
</dl>
</dd>
<dd>
<dl>
<dt>time offset</dt>
<dd>Offset for time data, alternative to shifting time data with <em>properties</em> key.</dd>
<dd><code>fileName: {&quot;time offset&quot;: {&quot;years&quot;: 10}</code></dd>
</dl>
</dd>
<dd>
<dl>
<dt>linear combinations</dt>
<dd>The concentrations of different chemical species may be tethered and scaled with a linear combination. Linear combinations are specified with the format shown below. Note: the properties linked with a linear combination must be of the <code>CONC</code> prefix.</dd>
</dl>
<pre><code class="has-line-data" data-line-start="217" data-line-end="226">filename: {&quot;linear combinations&quot;: combinationName: {
            &quot;properties&quot;: {
                &quot;CONC.Species1&quot;: {},
                &quot;CONC.Species2&quot;: {}
            },
            &quot;scale factor&quot;: &quot;1&quot;
        }
}
</code></pre>
</dd>
</dl>
</dd>
</dl>
<h4 class="code-line" data-line-start=226 data-line-end=227 ><a id="Input_file_formatting_226"></a>Input file formatting:</h4>
<p class="has-line-data" data-line-start="227" data-line-end="228"><strong>Evolving conditions input files should be comma-separated text files or NetCDF files.</strong></p>
<p class="has-line-data" data-line-start="229" data-line-end="231"><strong>Text files:</strong><br>
In text files, the variable names should appear on the first line, followed by a single line of data for each time the variable(s) should be updated during the simulation. The first variable should be <code>time</code>.</p>
<p class="has-line-data" data-line-start="232" data-line-end="233">The default unit for <code>time</code> values is seconds, and alternative units can be used by changing the column name to <code>time.min</code> or <code>time.hr</code>.</p>
<p class="has-line-data" data-line-start="234" data-line-end="236"><strong>NetCDF files</strong><br>
NetCDF files should have a dimension of <code>time</code>, and variables whose only dimension is <code>time</code>.</p>
<p class="has-line-data" data-line-start="237" data-line-end="239">Variable names should be structured as follows:<br>
<code>PREFIX.PropertyName</code></p>
<p class="has-line-data" data-line-start="240" data-line-end="241">The <code>PREFIX</code> indicates what type of property is being set. The property types corresponding to each recognized prefix are described below. The Property Name is the name of the property in the mechanism.</p>
<table class="table table-striped table-bordered">
<thead>
<tr>
<th style="text-align:center">Prefix</th>
<th>Property Type</th>
<th>Use</th>
<th>Default Unit</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:center"><code>CONC</code></td>
<td>Chemical species concentrations</td>
<td>Used with chemical species specified in the chemical mechanism</td>
<td>mol/m^3</td>
</tr>
<tr>
<td style="text-align:center"><code>ENV</code></td>
<td>Enviornmental conditions</td>
<td>Used to specify temperature and pressure</td>
<td>K or Pa</td>
</tr>
<tr>
<td style="text-align:center"><code>EMIS</code></td>
<td>Emission of a chemical species</td>
<td>Used to specify the rate constant for an emission reaction specified in the chemical mechansim</td>
<td>mol m-3 s-1</td>
</tr>
<tr>
<td style="text-align:center"><code>LOSS</code></td>
<td>First-order loss of a chemical species</td>
<td>Used to specify the rate constant for an loss reaction specified in the chemical mechansim</td>
<td>s-1</td>
</tr>
<tr>
<td style="text-align:center"><code>PHOT</code></td>
<td>Photolysis of a chemical species</td>
<td>Used to specify the rate constant for a photolysis reaction specified in the chemical mechansim</td>
<td>s-1</td>
</tr>
</tbody>
</table>
<hr>
<p class="has-line-data" data-line-start="250" data-line-end="251"><strong>Example evolving conditions configuration with three input files</strong></p>
<pre><code class="has-line-data" data-line-start="252" data-line-end="298" class="language-json">{
"<span class="hljs-attribute">evolving conditions</span>" : <span class="hljs-value">{
    "<span class="hljs-attribute">emissions.csv</span>" : <span class="hljs-value">{
      "<span class="hljs-attribute">properties</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">time.hr</span>" : <span class="hljs-value">{
          "<span class="hljs-attribute">shift first entry to</span>" :<span class="hljs-value">{
            "<span class="hljs-attribute">time zone</span>" : <span class="hljs-value"><span class="hljs-string">"UTC-8"</span></span>,
            "<span class="hljs-attribute">year</span>" : <span class="hljs-value"><span class="hljs-number">2020</span></span>,
            "<span class="hljs-attribute">month</span>" : <span class="hljs-value"><span class="hljs-number">6</span></span>,
            "<span class="hljs-attribute">day</span>" : <span class="hljs-value"><span class="hljs-number">10</span></span>,
            "<span class="hljs-attribute">hour</span>" : <span class="hljs-value"><span class="hljs-number">13</span>
          </span>}
        </span>}
      </span>}
    </span>}</span>,
    "<span class="hljs-attribute">wall_loss_rates_011519.txt</span>" : <span class="hljs-value">{
      "<span class="hljs-attribute">delimiter</span>" : <span class="hljs-value"><span class="hljs-string">";"</span></span>,
      "<span class="hljs-attribute">time axis</span>" : <span class="hljs-value"><span class="hljs-string">"columns"</span></span>,
      "<span class="hljs-attribute">properties</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">simtime</span>" : <span class="hljs-value">{
          "<span class="hljs-attribute">MusicBox name</span>" : <span class="hljs-value"><span class="hljs-string">"time"</span></span>,
          "<span class="hljs-attribute">units</span>" : <span class="hljs-value"><span class="hljs-string">"hr"</span></span>,
          "<span class="hljs-attribute">shift first entry to</span>" :<span class="hljs-value">{
            "<span class="hljs-attribute">time zone</span>" : <span class="hljs-value"><span class="hljs-string">"UTC-8"</span></span>,
            "<span class="hljs-attribute">year</span>" : <span class="hljs-value"><span class="hljs-number">2020</span></span>,
            "<span class="hljs-attribute">month</span>" : <span class="hljs-value"><span class="hljs-number">6</span></span>,
            "<span class="hljs-attribute">day</span>" : <span class="hljs-value"><span class="hljs-number">10</span></span>,
            "<span class="hljs-attribute">hour</span>" : <span class="hljs-value"><span class="hljs-number">13</span>
          </span>}
        </span>}</span>,
        "<span class="hljs-attribute">*</span>" : <span class="hljs-value">{
          "<span class="hljs-attribute">MusicBox name</span>" : <span class="hljs-value"><span class="hljs-string">"LOSS.*"</span></span>,
          "<span class="hljs-attribute">units</span>" : <span class="hljs-value"><span class="hljs-string">"min-1"</span>
        </span>}
      </span>}
    </span>}</span>,
    "<span class="hljs-attribute">parking_lot_photo_rates.nc</span>" : <span class="hljs-value">{
      "<span class="hljs-attribute">time offset</span>" : <span class="hljs-value">{ "<span class="hljs-attribute">years</span>" : <span class="hljs-value"><span class="hljs-number">15</span> </span>}</span>,
      "<span class="hljs-attribute">properties</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">*</span>" : <span class="hljs-value">{ "<span class="hljs-attribute">MusicBox name</span>" : <span class="hljs-value"><span class="hljs-string">"PHOT.*"</span> </span>}
      </span>}
    </span>}
  </span>}
</span>}

</code></pre>
<hr>
<p class="has-line-data" data-line-start="299" data-line-end="300"><strong>Example evolving conditions configuration with a linear combination scaling NOx concentrations</strong></p>
<pre><code class="has-line-data" data-line-start="301" data-line-end="320" class="language-json">{
"<span class="hljs-attribute">evolving conditions</span>": <span class="hljs-value">{
    "<span class="hljs-attribute">evolving_data.csv</span>" : <span class="hljs-value">{
      "<span class="hljs-attribute">properties</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">*</span>" : <span class="hljs-value">{"<span class="hljs-attribute">MusicBox name</span>": <span class="hljs-value"><span class="hljs-string">"CONC.*"</span></span>}
      </span>}</span>,
      "<span class="hljs-attribute">linear combinations</span>": <span class="hljs-value">{
          "<span class="hljs-attribute">NOx</span>": <span class="hljs-value">{
              "<span class="hljs-attribute">properties</span>": <span class="hljs-value">{
              "<span class="hljs-attribute">CONC.NO</span>": <span class="hljs-value">{}</span>,
              "<span class="hljs-attribute">CONC.NO2</span>": <span class="hljs-value">{}
              </span>}</span>,
              "<span class="hljs-attribute">scale factor</span>": <span class="hljs-value"><span class="hljs-number">1</span>
          </span>}
      </span>}
    </span>}
  </span>}
</span>}
</code></pre>
<hr>
<h3 class="code-line" data-line-start=321 data-line-end=322 ><a id="Model_Components_321"></a>Model Components</h3>
<h5 class="code-line" data-line-start=348 data-line-end=349 ><a id="Configuring_the_CAMP_solver_348"></a>Configuring the CAMP solver:</h5>
<p class="has-line-data" data-line-start="349" data-line-end="350"><strong>When using the CAMP solver, additional configuration files are required.</strong> By default, these are stored in a directory <code>camp_data</code>. Inside this folder:</p>
<p class="has-line-data" data-line-start="351" data-line-end="354">|—<code>config.json</code> — Points to <code>specise.json</code> and <code>mechanism.json</code>.<br>
|—<code>mechanism.json</code> — Contains chemical mechanism information.<br>
|—<code>species.json</code> — Describes absolute tolerances for species in the chemical mechanism.</p>
<p class="has-line-data" data-line-start="355" data-line-end="356"><strong>For more information on CAMP configuration files see the <a href="https://open-atmos.github.io/camp">CAMP documentation</a>.</strong></p>
<h5 class="code-line" data-line-start=357 data-line-end=358 ><a id="Model_component_options_with_CAMP_357"></a>Model component options with CAMP:</h5>
<dl>
<dt>type</dt>
<dd>Chemical solver type. <code>&quot;CAMP&quot;</code> is default.</dd>
<dt>configuration file</dt>
<dd>Path to CAMP configuration file. Default is <code>&quot;camp_data/config.json&quot;</code>.</dd>
<dt>override species</dt>
<dd>Overrides species concentration with specified value. By default, <code>M</code> is set to 1 mol/mol.</dd>
<dt>supress output:</dt>
<dd>Chemical species which will not be shown in output data by the model. By default <code>M</code> is supressed.</dd>
</dl>
<pre><code class="has-line-data" data-line-start="371" data-line-end="388" class="language-json">{
"<span class="hljs-attribute">model components</span>": <span class="hljs-value">[
        {
            "<span class="hljs-attribute">type</span>": <span class="hljs-value"><span class="hljs-string">"CAMP"</span></span>,
            "<span class="hljs-attribute">configuration file</span>": <span class="hljs-value"><span class="hljs-string">"camp_data/config.json"</span></span>,
            "<span class="hljs-attribute">override species</span>": <span class="hljs-value">{
                "<span class="hljs-attribute">M</span>": <span class="hljs-value">{
                    "<span class="hljs-attribute">mixing ratio mol mol-1</span>": <span class="hljs-value"><span class="hljs-number">1.0</span>
                </span>}
            </span>}</span>,
            "<span class="hljs-attribute">suppress output</span>": <span class="hljs-value">{
                "<span class="hljs-attribute">M</span>": <span class="hljs-value">{}
            </span>}
        </span>}
    ]
</span>}
</code></pre>
<hr>
<h3 class="code-line" data-line-start=390 data-line-end=391 ><a id="Example_configuration_files_390"></a>Example configuration files</h3>
<h5 class="code-line" data-line-start=392 data-line-end=393 ><a id="Configuration_for_simple_box_model_with_specified_reaction_rates_392"></a>Configuration for simple box model with specified reaction rates:</h5>
<h1 class="code-line" data-line-start=393 data-line-end=394 ><a id="_393"></a></h1>
<pre><code class="has-line-data" data-line-start="395" data-line-end="438" class="language-json">{
    "<span class="hljs-attribute">box model options</span>": <span class="hljs-value">{
        "<span class="hljs-attribute">grid</span>": <span class="hljs-value"><span class="hljs-string">"box"</span></span>,
        "<span class="hljs-attribute">chemistry time step [sec]</span>": <span class="hljs-value"><span class="hljs-number">1.0</span></span>,
        "<span class="hljs-attribute">output time step [sec]</span>": <span class="hljs-value"><span class="hljs-number">1.0</span></span>,
        "<span class="hljs-attribute">simulation length [hr]</span>": <span class="hljs-value"><span class="hljs-number">1.0</span>
    </span>}</span>,
    "<span class="hljs-attribute">chemical species</span>": <span class="hljs-value">{
        "<span class="hljs-attribute">a-pinene</span>": <span class="hljs-value">{
            "<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">8e-08</span>
        </span>}</span>,
        "<span class="hljs-attribute">O3</span>": <span class="hljs-value">{
            "<span class="hljs-attribute">initial value [mol m-3]</span>": <span class="hljs-value"><span class="hljs-number">2e-05</span>
        </span>}
    </span>}</span>,
    "<span class="hljs-attribute">environmental conditions</span>": <span class="hljs-value">{
        "<span class="hljs-attribute">temperature</span>": <span class="hljs-value">{
            "<span class="hljs-attribute">initial value [K]</span>": <span class="hljs-value"><span class="hljs-number">298.15</span>
        </span>}</span>,
        "<span class="hljs-attribute">pressure</span>": <span class="hljs-value">{
            "<span class="hljs-attribute">initial value [Pa]</span>": <span class="hljs-value"><span class="hljs-number">101325.0</span>
        </span>}
    </span>}</span>,
    "<span class="hljs-attribute">evolving conditions</span>": <span class="hljs-value">{}</span>,
    "<span class="hljs-attribute">initial conditions</span>": <span class="hljs-value">{
        "<span class="hljs-attribute">initial_reaction_rates.csv</span>": <span class="hljs-value">{}
    </span>}</span>,
    "<span class="hljs-attribute">model components</span>": <span class="hljs-value">[
        {
            "<span class="hljs-attribute">type</span>": <span class="hljs-value"><span class="hljs-string">"CAMP"</span></span>,
            "<span class="hljs-attribute">configuration file</span>": <span class="hljs-value"><span class="hljs-string">"camp_data/config.json"</span></span>,
            "<span class="hljs-attribute">override species</span>": <span class="hljs-value">{
                "<span class="hljs-attribute">M</span>": <span class="hljs-value">{
                    "<span class="hljs-attribute">mixing ratio mol mol-1</span>": <span class="hljs-value"><span class="hljs-number">1.0</span>
                </span>}
            </span>}</span>,
            "<span class="hljs-attribute">suppress output</span>": <span class="hljs-value">{
                "<span class="hljs-attribute">M</span>": <span class="hljs-value">{}
            </span>}
        </span>}
    ]
</span>}
</code></pre>
<hr>
<h5 class="code-line" data-line-start=439 data-line-end=440 ><a id="Configuration_with_multiple_input_files_and_linear_combinations_439"></a>Configuration with multiple input files and linear combinations:</h5>
<h1 class="code-line" data-line-start=440 data-line-end=441 ><a id="_440"></a></h1>
<pre><code class="has-line-data" data-line-start="442" data-line-end="495" class="language-json">{
  "<span class="hljs-attribute">box model options</span>" : <span class="hljs-value">{
    "<span class="hljs-attribute">grid</span>"                    : <span class="hljs-value"><span class="hljs-string">"box"</span></span>,
    "<span class="hljs-attribute">chemistry time step [s]</span>" : <span class="hljs-value"><span class="hljs-number">1.0</span></span>,
    "<span class="hljs-attribute">output time step [s]</span>"    : <span class="hljs-value"><span class="hljs-number">10.0</span></span>,
    "<span class="hljs-attribute">simulation length [s]</span>"   : <span class="hljs-value"><span class="hljs-number">50.0</span>
  </span>}</span>,
  "<span class="hljs-attribute">initial conditions</span>" : <span class="hljs-value">{
    "<span class="hljs-attribute">init_O_O1D_O3.csv</span>" : <span class="hljs-value">{
      "<span class="hljs-attribute">properties</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">CONC.O3</span>" : <span class="hljs-value">{ "<span class="hljs-attribute">variability</span>" : <span class="hljs-value"><span class="hljs-string">"tethered"</span> </span>}
      </span>}</span>,
      "<span class="hljs-attribute">linear combinations</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">atomic oxygen</span>" : <span class="hljs-value">{
          "<span class="hljs-attribute">properties</span>" : <span class="hljs-value">{
            "<span class="hljs-attribute">CONC.O</span>" : <span class="hljs-value">{ }</span>,
            "<span class="hljs-attribute">CONC.O1D</span>" : <span class="hljs-value">{ }
          </span>}
        </span>}
      </span>}
    </span>}
  </span>}</span>,
  "<span class="hljs-attribute">environmental conditions</span>" : <span class="hljs-value">{
    "<span class="hljs-attribute">temperature</span>" : <span class="hljs-value">{ "<span class="hljs-attribute">initial value [K]</span>"   : <span class="hljs-value"><span class="hljs-number">298.15</span> </span>}</span>,
    "<span class="hljs-attribute">pressure</span>"    : <span class="hljs-value">{ "<span class="hljs-attribute">initial value [atm]</span>" : <span class="hljs-value"><span class="hljs-number">1.0</span>    </span>}
  </span>}</span>,
  "<span class="hljs-attribute">evolving conditions</span>" : <span class="hljs-value">{
    "<span class="hljs-attribute">evo_N2_Ar_O2.csv</span>" : <span class="hljs-value">{
      "<span class="hljs-attribute">linear combinations</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">N2 Ar</span>" : <span class="hljs-value">{
          "<span class="hljs-attribute">properties</span>" : <span class="hljs-value">{
            "<span class="hljs-attribute">CONC.N2</span>" : <span class="hljs-value">{ }</span>,
            "<span class="hljs-attribute">CONC.Ar</span>" : <span class="hljs-value">{ }
          </span>}
        </span>}
      </span>}
    </span>}</span>,
    "<span class="hljs-attribute">emit_all.csv</span>" : <span class="hljs-value">{ }
  </span>}</span>,
  "<span class="hljs-attribute">model components</span>" : <span class="hljs-value">[
    {
      "<span class="hljs-attribute">type</span>" : <span class="hljs-value"><span class="hljs-string">"CAMP"</span></span>,
      "<span class="hljs-attribute">configuration file</span>" : <span class="hljs-value"><span class="hljs-string">"camp_data/config.json"</span></span>,
      "<span class="hljs-attribute">override species</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">M</span>" : <span class="hljs-value">{ "<span class="hljs-attribute">mixing ratio mol mol-1</span>" : <span class="hljs-value"><span class="hljs-number">1.0</span> </span>}
      </span>}</span>,
      "<span class="hljs-attribute">suppress output</span>" : <span class="hljs-value">{
        "<span class="hljs-attribute">M</span>" : <span class="hljs-value">{ }
      </span>}
    </span>}
  ]
</span>}
</code></pre>
<hr>

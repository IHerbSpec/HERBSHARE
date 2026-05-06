################################################################################
### About panel

about_panel_ui <- function(id) {
  ns <- NS(id)
  fluidRow(
    column(width = 8, offset = 2,
           br(),
           HTML("<h1 align='center' style='color:#ffffff; font-weight:bold;'>About HERBSPHERE</h1>"),
           br(),
           
           wellPanel(
             style = "background-color: #162623; border: 2px solid #004040; color: white;",
             
             # Version and Links
             HTML("<p align='center' style='font-size: 16px; color: white;'>
              <strong>HERBSPHERE Version 0.1 (Beta)</strong> |
              <img src='github.png' width='20px' height='auto' style='vertical-align: middle;'>
              <a target='_blank' rel='noopener noreferrer' href='https://github.com/ASCEND-BII/SpecTraits' style='color: #c0c0c0; text-decoration: none;'>GitHub</a>
             </p>"),
             br(),
             
             # Motivation Section
             HTML("<h5 style='color: #c0c0c0; border-bottom: 1px solid #c0c0c0; padding-bottom: 5px; font-weight: bold;'><strong>Motivation</strong></h5>"),
             HTML("<p style='text-align: justify; color: white;'>
              The digitization of specimen data—the conversion of physical samples into accessible 
              digital content—combined with data science workflows is driving the discovery and 
              use of herbarium collections at an unprecedented scale. <strong>HERBSPHERE</strong>—HERBerbarium 
              SPectral Hub for Research and Exploration—aims to advance the next generation 
              of specimen digitization through the exploration and use of reflectance 
              spectroscopy data from herbarium specimens.
              </p>"),
             HTML("<p style='text-align: justify; color: white;'>
              Our motivation is to make spectral data from herbarium specimens more accessible, 
              usable, and impactful. Through <strong>HERBSPHERE</strong>, we aim to facilitate discovery,
              accelerate research, and unlock the hidden potential of these vast plant collections—transforming 
              them into dynamic laboratories that can inform our understanding of biodiversity, 
              environmental change, and the future of plant science.
              </p>"),
             br(),
             
             # Citation Section
             HTML("<h5 style='color: #c0c0c0; border-bottom: 1px solid #c0c0c0; padding-bottom: 5px; font-weight: bold;'>Citation</h5>"),
             HTML("<p style='text-align: justify; color: white;'>
              If you use <strong>HERBSPHERE</strong> in your research, please cite:
              </p>"),
             HTML("<div style='background-color: #1f3632; padding: 15px; border-left: 4px solid #c0c0c0; margin: 10px 0; position: relative; border-radius: 5px;'>
              <pre id='citation-text' style='margin: 0; font-family: monospace; padding-right: 50px; font-size: 12px; white-space: pre-wrap; overflow-x: auto; color: white;'>@software{HERBSPHERE,
  author = {Guzmán J.A., White D.M., and Cavender-Bares J.},
  title = {HERBSPHERE: Herbaria Spectral Hub for Research and Exploration},
  year = {2026},
  version = {0.1},
  url = {https://github.com/IHerbSpec/HERBSPHERE}
}</pre>
              <button id='copy-citation-btn' onclick='copyCitation()'
                      style='position: absolute; top: 10px; right: 10px;
                             background-color: #6c757d; color: white; border: none;
                             border-radius: 5px; padding: 8px 12px; cursor: pointer;
                             font-size: 14px; font-weight: bold;'
                      title='Copy BibTeX citation to clipboard'>
                📋 Copy BibTeX
              </button>
              <span id='copy-feedback' style='position: absolute; top: 10px; right: 10px;
                                             background-color: #28a745; color: white;
                                             padding: 8px 12px; border-radius: 5px;
                                             font-size: 14px; display: none;'>
                ✓ Copied!
              </span>
              </div>"),
             tags$script(HTML("
               function copyCitation() {
                 var citationText = document.getElementById('citation-text').textContent;
                 var btn = document.getElementById('copy-citation-btn');
                 var feedback = document.getElementById('copy-feedback');
                 function showFeedback() {
                   btn.style.display = 'none';
                   feedback.style.display = 'inline-block';
                   setTimeout(function() {
                     btn.style.display = 'inline-block';
                     feedback.style.display = 'none';
                   }, 2000);
                 }
                 var ta = document.createElement('textarea');
                 ta.value = citationText;
                 ta.style.position = 'fixed';
                 ta.style.opacity = '0';
                 document.body.appendChild(ta);
                 ta.focus();
                 ta.select();
                 try { document.execCommand('copy'); showFeedback(); } catch(err) { console.error(err); }
                 document.body.removeChild(ta);
               }
             ")),
             br(),
             
             # Funding Section
             HTML("<h5 style='color: #c0c0c0; border-bottom: 1px solid #c0c0c0; padding-bottom: 5px; font-weight: bold;'>Funding</h5>"),
             HTML("<p style='text-align: justify; color: white;'>
              The development of <strong>HERBSPHERE</strong> is supported by:
              </p>"),
             HTML("<div style='text-align: center; margin: 20px 0;'>
                <img src='HUH_white.png' height='130px' style='display: inline-block;'>
              </div>
              <div style='display: flex; justify-content: center; align-items: center; margin: 20px 0; gap: 40px;'>
                <img src='HDSI_white.png' height='60px'>
                <img src='FAS_white.png' height='60px'>
              </div>
              <div style='display: flex; justify-content: center; align-items: center; margin: 20px 0; gap: 40px;'>
                <img src='ASCEND.png' height='120px'>
                <img src='NSF.png' height='120px'>
              </div>"),
             br(),
             
             # Licence Section
             HTML("<h5 style='color: #c0c0c0; border-bottom: 1px solid #c0c0c0; padding-bottom: 5px; font-weight: bold;'>Licence</h5>"),
             HTML("<p style='text-align: justify; color: white;'>
              HERBSPHERE is released under the <a href='https://opensource.org/licenses/MIT' target='_blank' style='color: #c0c0c0;'>MIT License</a>.
              </p>"),
             br(),
             
             # Contribute Section
             HTML("<h5 style='color: #c0c0c0; border-bottom: 1px solid #c0c0c0; padding-bottom: 5px; font-weight: bold;'>Contribute</h5>"),
             HTML("<p style='text-align: justify; color: white;'>
                  <strong>HERBSPHERE</strong> is a community-driven platform that grows through open-science and collaboration. 
                  The application harvests spectral datasets from publicly available repositories, 
                  with a focus on standardized, well-documented contributions. To ensure data can be efficiently 
                  discovered, integrated, and reused, we strongly encourage contributors to follow common data 
                  standards from the <strong>IHerbSpec</strong> initiative, including the use of the IHerbSpec metadata 
                  and depositing datasets in the IHerbSpec-Dataverse repository. These standards 
                  enable seamless data harvesting and maximize the visibility and impact of your work.
                  </p>
                  <p style='text-align: justify; color: white;'>
                  You can contribute in the following ways:
                  </p>
                  <ol style='color: white;'>
                  <li>Share your specimen spectra data by following the <a href='https://iherbspec.github.io/' target='_blank' style='color: #c0c0c0;'>IHerbSpec</a> guidelines and depositing your data in the IHerbSpec Dataverse.</li>
                  <li>Help develop open-source tools and workflows that use HERBSPHERE for research and analysis.</li>
                  <li>Report problems and help us identify, debug, and resolve issues.</li>
                  </ol>"),

             # Disclaimer Section
             HTML("<h5 style='color: #c0c0c0; border-bottom: 1px solid #c0c0c0; padding-bottom: 5px; font-weight: bold;'>Disclaimer</h5>"),
             HTML("<p style='text-align: justify; color: white;'>
               All information made available on HERBSPHERE, including any information, outputs, or materials generated 
               by HERBSPHERE, is provided on an “as is” and “as available” basis, in good faith, and without representations 
               or warranties of any kind, whether express, implied, or statutory, including, without limitation, warranties of 
               accuracy, completeness, reliability, adequacy, validity, availability, merchantability, fitness for a particular 
               purpose, or non-infringement. To the fullest extent permitted by applicable law, HERBSPHERE and its affiliates, 
               contributors, and operators disclaim any and all liability for any loss, damage, claim, cost, or expense of any 
               kind, whether direct, indirect, incidental, consequential, special, exemplary, or punitive, arising out of or 
               in connection with your access to, use of, or reliance on HERBSPHERE or any information made available on or 
               generated by HERBSPHERE. Your use of HERBSPHERE and any reliance on its content, outputs, or materials is solely 
               at your own risk.
              </p>"),
             br(),

             # Contact Section
             HTML("<h5 style='color: #c0c0c0; border-bottom: 1px solid #c0c0c0; padding-bottom: 5px; font-weight: bold;'>Contact</h5>"),
             HTML("<p style='text-align: justify; color: white;'>
              For questions, bug reports, or feature requests, please visit our
              <a href='https://github.com/IHerbSpec/HERBSPHERE/issues' target='_blank' style='color: #c0c0c0; text-decoration: none;'>GitHub Issues page</a>
              or contact the development team.
              </p>"),
             br(),

             HTML("<p align='center' style='color: #d0d0d0; font-size: 14px;'>
              Last updated: 2026-05-05
              </p>")
           )
    )
  )
}
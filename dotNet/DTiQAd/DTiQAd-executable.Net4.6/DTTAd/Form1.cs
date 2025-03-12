using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;
using static System.Windows.Forms.VisualStyles.VisualStyleElement;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.Button;

namespace DTTAd
{
    public partial class Form1 : Form
    {
        private object locationIDreg;
        private object brandreg;
        private object companyreg;
        private object guidreg;
        private DisplayState state;
        

        public class DisplayState
        {
            public string deviceName;
        }

        public Form1()
        {
            InitializeComponent();
            this.Visible = false;

            state = new DisplayState();
            // Set the form to full screen
            this.WindowState = FormWindowState.Maximized;   // Maximizes the form on start
            this.FormBorderStyle = FormBorderStyle.None;    // Removes the border and title bar
            this.Bounds = Screen.PrimaryScreen.Bounds;      // Ensures the form occupies the full screen area

            // Optional: Disable minimize and maximize buttons
            this.MinimizeBox = false;
            this.MaximizeBox = false;

            // Prevent resizing by setting the size of the form (locked to screen size)
            this.ClientSize = Screen.PrimaryScreen.Bounds.Size;  // Ensure client area fills the screen

        }

        protected override void WndProc(ref Message m)
        {
            // Block the WM_SYSCOMMAND message with SC_MAXIMIZE
            const int WM_SYSCOMMAND = 0x0112;
            const int SC_MINIMIZE = 0xF020;


            // Block minimizing
            if (m.Msg == WM_SYSCOMMAND && (int)m.WParam == SC_MINIMIZE)
            {
                return; // Prevent minimizing
            }

            base.WndProc(ref m); // Pass the message to the base class
            m.Msg = WM_SYSCOMMAND;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, ref RECT lpRect);

        private void Form1_Load(object sender, EventArgs e)
        {
            this.Visible = false;
            // Disable button
            button1.Enabled = false;
            // Uncheck checkbox
            checkBox1.Checked = false;

            // Set Leave a message information on unfocused textbox

            textBox1.Text = "Thank You, DTiQ Technologies Inc.";
            //textBox1.Text = "Leave a message (i.e. email)...";
            //textBox1.ForeColor = Color.LightGray;

            try
            {
                foreach (var screen in System.Windows.Forms.Screen.AllScreens)
                {
                    if (screen.Primary)
                    {
                        //MessageBox.Show($"The main display is: {screen.DeviceName}");
                        //var screenPrimary = screen.DeviceName;
                        state.deviceName = screen.DeviceName;
                    }
                }

                //var firefoxProcesses = Process.GetProcessesByName("geosyscenter");
                var firefoxProcesses = Process.GetProcessesByName("firefox");
                if (firefoxProcesses.Length == 0)
                {
                    //MessageBox.Show("Firefox is not running.");
                    //return;
                    this.Close();
                }

                Process firefoxProcessWithHandle = null;

                foreach (var process in firefoxProcesses)
                {
                    if (process.MainWindowHandle != IntPtr.Zero)
                    {
                        firefoxProcessWithHandle = process;
                        break;
                    }
                }

                if (firefoxProcessWithHandle == null)
                {
                    MessageBox.Show("No Firefox process has a main window handle.");
                    return;
                }

                var windowHandle = firefoxProcessWithHandle.MainWindowHandle;
                var rect = new RECT();

                if (GetWindowRect(windowHandle, ref rect))
                {
                    // Use absolute value for Y to handle maximized windows correctly
                    var windowLocation = new System.Drawing.Rectangle(rect.Left, Math.Abs(rect.Top), rect.Right - rect.Left, rect.Bottom - rect.Top);
                    var screen = GetScreenForWindow(windowLocation);

                    
                    if ((screen != null))
                    //MessageBox.Show($"Primary: {state.deviceName}, firefoxscreen: {screen.DeviceName}");
                    //if ({ state.deviceName} == { screen.DeviceName})
                    if (String.Equals(state.deviceName, screen.DeviceName, StringComparison.OrdinalIgnoreCase))
                    {
                            {
                            //MessageBox.Show($"Firefox is on display: {screen.DeviceName}");
                            // Position the form on the same screen
                            this.StartPosition = FormStartPosition.Manual;
                            this.Location = screen.WorkingArea.Location;
                            this.ClientSize = screen.WorkingArea.Size;

                            // Show the form
                            this.Show();
                        }
                    }
                    else
                    {
                        //MessageBox.Show("Firefox is not visible on any display.");
                        this.Close();
                    }
                }
                else
                {
                    //MessageBox.Show("Unable to retrieve the Firefox window location.");
                    this.Close();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"An error occurred: {ex.Message}");
            }
        }

        // Updated method to detect screen for maximized and non-maximized windows
        private Screen GetScreenForWindow(System.Drawing.Rectangle windowLocation)
        {
            Console.WriteLine($"Window Location: {windowLocation}");

            // Check if the window's size matches any screen's working area (maximized window)
            foreach (var screen in Screen.AllScreens)
            {
                // If the window width and height match screen size, it's likely maximized
                if (windowLocation.Width == screen.WorkingArea.Width && windowLocation.Height == screen.WorkingArea.Height)
                {
                    // Maximized window: match the screen's working area
                    Console.WriteLine($"Maximized Firefox window detected on screen: {screen.DeviceName}");
                    return screen;
                }
                else
                {
                    // Non-maximized: check if the window intersects with the screen's working area
                    if (windowLocation.Left >= screen.WorkingArea.Left &&
                        windowLocation.Right <= screen.WorkingArea.Right &&
                        windowLocation.Top >= screen.WorkingArea.Top &&
                        windowLocation.Bottom <= screen.WorkingArea.Bottom)
                    {
                        Console.WriteLine($"Non-maximized Firefox window detected on screen: {screen.DeviceName}");
                        return screen;
                    }
                }
            }

            // If no match is found, check the window position relative to all screens' areas
            var closestScreen = Screen.AllScreens
                .OrderBy(screen => GetDistanceToScreenCenter(windowLocation, screen))
                .FirstOrDefault();

            return closestScreen;
        }

        // Calculate the distance from the center of the screen to the window's center
        private double GetDistanceToScreenCenter(System.Drawing.Rectangle windowLocation, Screen screen)
        {
            var windowCenter = new System.Drawing.Point(windowLocation.Left + windowLocation.Width / 2, windowLocation.Top + windowLocation.Height / 2);
            var screenCenter = new System.Drawing.Point(screen.WorkingArea.Left + screen.WorkingArea.Width / 2, screen.WorkingArea.Top + screen.WorkingArea.Height / 2);

            // Calculate Euclidean distance between window center and screen center
            return Math.Sqrt(Math.Pow(windowCenter.X - screenCenter.X, 2) + Math.Pow(windowCenter.Y - screenCenter.Y, 2));
        }


        private void button1_Click(object sender, EventArgs e)
        {
            /*
            try
            {

                // Store text in textbox
                string messagetextbox;
                messagetextbox = textBox1.Text;
                
                                // Define breeze script
                                string script = @"
                param(
                    $textbox, 
                    $locationid,
                    $brand,
                    $company,
                    $guid
                    )

                ###

                function Invoke-Breezev2 {
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

                    ## === FUNCTION SPACE START ===


                    ## === END OF FUNCTIONS SPACE ===
                    function getIdToken {    
                        $json = 
                        @{
                            ""AuthFlow""       = ""USER_PASSWORD_AUTH""
                            ""AuthParameters"" = @{
                                ""PASSWORD"" = 'hRddjQK1VFTHM3jLTMkS!'
                                ""USERNAME"" = ""breeze-prod""
                            }
                            ""ClientId""       = '7nig6316ca3lt7ofs96ci24hl'
                        } | ConvertTo-Json

                        $var = Invoke-RestMethod `
                            -Method POST `
                            -Uri ""https://cognito-idp.us-east-1.amazonaws.com/"" `
                            -Body $json `
                            -Headers @{
                            ""Content-Type"" = ""application/x-amz-json-1.1""
                            ""x-amz-target"" = ""AWSCognitoIdentityProviderService.InitiateAuth"" 
                        }

                        #$var.AuthenticationResult
                        $script:idToken = $var.AuthenticationResult.IdToken #expires every 3600s/1hr 
                    }


                    function sendRestData {
                        #$getLocationID = Get-ItemPropertyValue 'HKLM:\SOFTWARE\DTIQ' -Name 'LocationID'

                        if ($locationid -eq '') {
                            $locationid = 'NA'
                            $brand = 'NA'
                            $company = 'NA'
                            $guid = 'NA'
                        }

                        $body = @{
                            locationId      = $locationid
                            locationName    = $brand
                            timestamp       = Get-Date -UFormat ""%m/%d/%Y %H:%M:%S""
                            timezoneId      = Get-Date -UFormat ""%Z""
                            scriptName      = ""LegacyDTTInfo""
                            scriptId        = ""16""
                            executionDate   = Get-Date -UFormat ""%m/%d/%Y %H:%M:%S""
                            result          = $textbox
                            optionalResult1 = $company 
                            optionalResult2 = $guid
                            errorCode       = ""NULL""
                            errorDetails    = ""NULL""
                            #teamViewerId    = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\TeamViewer\).ClientID
                            controllerName  = $env:computername
                        } | ConvertTo-Json

                        #$body

                        ### PROD API
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                        Invoke-RestMethod `
                            -Method Post `
                            -Uri ""https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/ScriptExecution"" `
                            -Body $body `
                            -ContentType 'application/json' `
                            -Headers @{
                            ""Authorization"" = $idToken
                        }
                        #>
                    }

                    getIdToken
                    sendRestData
                }

                Invoke-Breezev2
                ";


                                using (PowerShell ps = PowerShell.Create())
                                {
                                    // Set proper hive (localkey) in registery
                                    RegistryKey localKey;
                                    if (Environment.Is64BitOperatingSystem)
                                        localKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64);
                                    else
                                        localKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry32);

                                    // Store machine information in variables
                                    string regPath = @"SOFTWARE\DTIQ";

                                    if (localKey.OpenSubKey(regPath) != null)
                                    {
                                        locationIDreg = localKey.OpenSubKey(regPath).GetValue("LocationID", "notfound").ToString();
                                        brandreg = localKey.OpenSubKey(regPath).GetValue("Brand", "notfound").ToString();
                                        companyreg = localKey.OpenSubKey(regPath).GetValue("Company", "notfound").ToString();
                                        guidreg = localKey.OpenSubKey(regPath).GetValue("GUID", "notfound").ToString();
                                    }
                                    else if (localKey.OpenSubKey(regPath) == null)
                                    {
                                        locationIDreg = Environment.MachineName;
                                        brandreg = "NA";
                                        companyreg = "NA";
                                        guidreg = "NA";
                                    }
                                    else
                                    {
                                        this.Close();
                                    }

                                    // Define parameters as a dictionary
                                    var parameters = new Dictionary<string, object>
                                    {
                                        { "textbox", messagetextbox },
                                        { "locationid", locationIDreg },
                                        { "brand", brandreg },
                                        { "company", companyreg },
                                        { "guid", guidreg }
                                    };

                                    // Add script and pass parameters - dictionary
                                    ps.AddScript(script).AddParameters(parameters);

                                    // Lock button and write action message
                                    button1.Enabled = false;
                                    button1.Text = "Sending";


                                    // Execute
                                    var results = ps.Invoke();

                                    // Show output ScriptExecutionID in console 
                                    foreach (var result in results)
                                    {
                                        Console.WriteLine(result);
                                    }

                                }
                                // Close app after is done
                                this.Close();
                            }
                            catch (Exception ex)
                            {
                                // Handle exceptions
                                // MessageBox.Show($"An error occurred: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);

                                // Dont send anything if unable, close gracefully
                                this.Close();
                            }
              */
            this.Close();
        }

        private void textBox1_Enter_1(object sender, EventArgs e)
        {
            // Remove Leave a message on textbox on Enter action
            if (textBox1.Text == "Leave a message (i.e. email)...")
            {
                textBox1.Text = "";
                textBox1.ForeColor = Color.Black;
            }
        }

        private void textBox1_Leave(object sender, EventArgs e)
        {
            // Show Leave a message on textbox on Enter action
            if (textBox1.Text == "")
            {
                textBox1.Text = "Leave a message (i.e. email)...";
                textBox1.ForeColor = Color.LightGray;
            }
        }

        private void linkLabel1_LinkClicked_1(object sender, LinkLabelLinkClickedEventArgs e)
        {
            // Mark the link as visited (optional)
            linkLabel1.LinkVisited = true;

            // Open a URL in the default browser
            System.Diagnostics.Process.Start(new ProcessStartInfo
            {
                FileName = "https://www.dtiq.com/solutions", // Replace with your URL
                UseShellExecute = true
            });
        }

        private void checkBox1_CheckedChanged(object sender, EventArgs e)
        {
            // Disable button when not agree to terms
            if (checkBox1.Checked == false)
            {
                button1.Enabled = false;
            }
            else
            {
                button1.Enabled = true;
            }
        }
    }
}

// Google Apps Script for Mosque Management
// This script acts as a secure middleware between the Flutter app and Google Sheets

// Configuration
const API_KEY = 'AIzaSyDZZmfYFIy5anY8K0kqPJse_-TfiKhugVo'; // Replace with your actual API key

// Main doGet function for testing in browser
function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    message: "Google Apps Script for Mosque Management is running. Use POST requests with the appropriate action parameter."
  })).setMimeType(ContentService.MimeType.JSON);
}

// Main doPost function to handle all requests
function doPost(e) {
  // Set CORS headers
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json'
  };

  try {
    // Handle preflight request
    if (e.method === 'OPTIONS') {
      return ContentService.createTextOutput(JSON.stringify({}))
        .setMimeType(ContentService.MimeType.JSON);
    }

    // Parse the incoming request
    const request = JSON.parse(e.postData.contents);
    const action = request.action;
    const spreadsheetId = request.spreadsheetId;
    
    // Verify API key if provided
    if (request.apiKey && request.apiKey !== API_KEY) {
      return ContentService.createTextOutput(JSON.stringify(createErrorResponse('Invalid API key')))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // Verify spreadsheet ID is provided (except for createNewSpreadsheet action)
    if (!spreadsheetId && action !== 'createNewSpreadsheet') {
      return ContentService.createTextOutput(JSON.stringify(createErrorResponse('Spreadsheet ID is required')))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // Handle different actions
    let response;
    switch (action) {
      case 'getMosqueName':
        response = getMosqueName(spreadsheetId);
        break;
      case 'getFundData':
        response = getFundData(spreadsheetId, request.year);
        break;
      case 'getTransactions':
        response = getTransactions(spreadsheetId);
        break;
      case 'getDeductions':
        response = getDeductions(spreadsheetId);
        break;
      case 'getSummary':
        response = getSummary(spreadsheetId);
        break;
      case 'getRecoveryData':
        response = getRecoveryData(spreadsheetId);
        break;
      case 'getPayerData':
        response = getPayerData(spreadsheetId, request.year);
        break;
      case 'getPayerDataForYear':
        response = getPayerDataForYear(spreadsheetId, request.year);
        break;
      case 'getAllYearsPayerData':
        response = getAllYearsPayerData(spreadsheetId);
        break;
      case 'getRecoveryDataForRestoration':
        response = getRecoveryDataForRestoration(spreadsheetId);
        break;
      case 'createNewSpreadsheet':
        response = createNewSpreadsheet(request.mosqueName, request.email);
        break;
      case 'saveRecoveryData':
        response = saveRecoveryData(spreadsheetId, request.recoveryData);
        break;
      case 'exportData':
        response = exportData(spreadsheetId, request.sheetName, request.data);
        break;
      case 'createSheetIfNotExists':
        response = createSheetIfNotExists(spreadsheetId, request.sheetName);
        break;
      case 'getPayerTransactions':
        response = getPayerTransactions(spreadsheetId, request.payerName);
        break;
      default:
        response = createErrorResponse('Invalid action');
    }

    // Return response
    return ContentService.createTextOutput(JSON.stringify(response))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    // Create error response
    const errorResponse = createErrorResponse(error.toString());
    return ContentService.createTextOutput(JSON.stringify(errorResponse))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// Helper function to create error responses
function createErrorResponse(message) {
  return {
    success: false,
    error: message
  };
}

// Helper function to create success responses
function createSuccessResponse(data) {
  return {
    success: true,
    data: data
  };
}

// Get mosque name from spreadsheet title
function getMosqueName(spreadsheetId) {
  try {
    Logger.log("getMosqueName called with spreadsheetId: " + spreadsheetId);
    
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const title = spreadsheet.getName();
    
    Logger.log("Spreadsheet title: " + title);
    
    const mosqueName = title.replace(' - Mosque Management', '').trim();
    
    Logger.log("Extracted mosque name: " + mosqueName);
    
    return {
      success: true,
      mosqueName: mosqueName
    };
  } catch (error) {
    Logger.log("Error in getMosqueName: " + error.toString());
    return createErrorResponse(error.toString());
  }
}

// Get fund data for a specific year
function getFundData(spreadsheetId, year) {
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheetName = `FundData_${year}`;
  const sheet = spreadsheet.getSheetByName(sheetName);
  
  if (!sheet) {
    return createSuccessResponse([]);
  }
  
  const data = sheet.getDataRange().getValues();
  return createSuccessResponse(data);
}

// Get all transactions
function getTransactions(spreadsheetId) {
  try {
    Logger.log("Getting transactions from Recovery_Data sheet instead of Transactions sheet");
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = spreadsheet.getSheetByName('Recovery_Data');
  
  if (!sheet) {
      Logger.log("Recovery_Data sheet not found");
    return createSuccessResponse([]);
  }
  
    const recoveryData = sheet.getDataRange().getValues();
    const transactionsList = [];
    let payerNames = []; // Array to hold payer names
    
    // First find the payers row to get names
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      if (row.length >= 2 && row[0] === 'Payers') {
        payerNames = row[1].split(',').map(name => name.trim());
        break;
      }
    }
    
    // Now process the transactions
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      if (row.length >= 2 && row[0] === 'Transactions') {
        try {
          // Transaction format in Recovery_Data: ID|PayerID|Amount|Type|Category|Date
          const parts = row[1].split('|');
          if (parts.length >= 6) {
            // Only process income transactions
            if (parts[3] === 'TxnTyp.inc') {
              const payerId = parseInt(parts[1]);
              const payerName = (payerId > 0 && payerId <= payerNames.length) ? 
                               payerNames[payerId - 1] : 'Unknown';
              const amount = parseFloat(parts[2]);
              const dateStr = parts[5];
              
              // Format date to DD/MM/YYYY if it's in ISO format
              let formattedDate = dateStr;
              try {
                if (dateStr.includes('T')) {
                  // Parse ISO date and format to DD/MM/YYYY
                  const date = new Date(dateStr);
                  const day = date.getDate().toString().padStart(2, '0');
                  const month = (date.getMonth() + 1).toString().padStart(2, '0');
                  const year = date.getFullYear();
                  formattedDate = day + '/' + month + '/' + year;
                }
              } catch (e) {
                Logger.log("Error formatting date: " + dateStr + " - " + e.toString());
                // Keep original date format if parsing fails
              }
              
              // Format as expected by the app: [payerName, amount, dateStr]
              transactionsList.push([payerName, amount, formattedDate]);
            }
          }
        } catch (e) {
          Logger.log("Error parsing transaction: " + e.toString());
          // Continue with other transactions
        }
      }
    }
    
    Logger.log("Processed " + transactionsList.length + " transactions from Recovery_Data");
    return createSuccessResponse(transactionsList);
  } catch (error) {
    Logger.log("Error in getTransactions: " + error.toString());
    return createErrorResponse(error.toString());
  }
}

// Get all deductions
function getDeductions(spreadsheetId) {
  try {
    Logger.log("Getting deductions from Recovery_Data sheet instead of Deductions sheet");
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = spreadsheet.getSheetByName('Recovery_Data');
  
  if (!sheet) {
      Logger.log("Recovery_Data sheet not found");
    return createSuccessResponse([]);
  }
  
    const recoveryData = sheet.getDataRange().getValues();
    const deductionsList = [];
    
    // Process the transactions to extract deductions
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      if (row.length >= 2 && row[0] === 'Transactions') {
        try {
          // Transaction format in Recovery_Data: ID|PayerID|Amount|Type|Category|Date
          const parts = row[1].split('|');
          if (parts.length >= 6) {
            // Only process deduction transactions
            if (parts[3] === 'TxnTyp.ded') {
              const category = parts[4];
              const amount = parseFloat(parts[2]);
              const dateStr = parts[5];
              
              // Format date to DD/MM/YYYY if it's in ISO format
              let formattedDate = dateStr;
              try {
                if (dateStr.includes('T')) {
                  // Parse ISO date and format to DD/MM/YYYY
                  const date = new Date(dateStr);
                  const day = date.getDate().toString().padStart(2, '0');
                  const month = (date.getMonth() + 1).toString().padStart(2, '0');
                  const year = date.getFullYear();
                  formattedDate = day + '/' + month + '/' + year;
                }
              } catch (e) {
                Logger.log("Error formatting date: " + dateStr + " - " + e.toString());
                // Keep original date format if parsing fails
              }
              
              // Format as expected by the app: [category, amount, dateStr]
              deductionsList.push([category, amount, formattedDate]);
            }
          }
        } catch (e) {
          Logger.log("Error parsing deduction: " + e.toString());
          // Continue with other transactions
        }
      }
    }
    
    Logger.log("Processed " + deductionsList.length + " deductions from Recovery_Data");
    return createSuccessResponse(deductionsList);
  } catch (error) {
    Logger.log("Error in getDeductions: " + error.toString());
    return createErrorResponse(error.toString());
  }
}

// Get summary data
function getSummary(spreadsheetId) {
  try {
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    Logger.log("Accessing spreadsheet: " + spreadsheet.getName());
    
    const sheet = spreadsheet.getSheetByName('Summary');
    
    if (!sheet) {
      Logger.log("Summary sheet not found");
      return createSuccessResponse([]);
    }
    
    Logger.log("Summary sheet found: " + sheet.getName());
    
    const dataRange = sheet.getDataRange();
    const values = dataRange.getValues();
    
    Logger.log("Summary data rows: " + values.length + ", columns: " + (values.length > 0 ? values[0].length : 0));
    
    // If the data is a single row, make sure it's formatted correctly
    if (values.length === 1) {
      const row = values[0];
      // Convert any string numbers to actual numbers
      const numericRow = row.map(item => {
        const num = parseFloat(item);
        return isNaN(num) ? item : num;
      });
      Logger.log("Summary data (converted): " + JSON.stringify([numericRow]));
      return createSuccessResponse([numericRow]);
    }
    
    Logger.log("Summary data: " + JSON.stringify(values));
    return createSuccessResponse(values);
  } catch (error) {
    Logger.log("Error in getSummary: " + error.toString());
    return createErrorResponse("Error getting summary data: " + error.toString());
  }
}

// Get recovery data
function getRecoveryData(spreadsheetId) {
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = spreadsheet.getSheetByName('Recovery_Data');
  
  if (!sheet) {
    return createSuccessResponse([]);
  }
  
  const data = sheet.getDataRange().getValues();
  return createSuccessResponse(data);
}

// Get payer data for a specific year
function getPayerDataForYear(spreadsheetId, year) {
  try {
    Logger.log("Getting payer data for year " + year + " from Recovery_Data sheet");
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = spreadsheet.getSheetByName('Recovery_Data');
  
  if (!sheet) {
      Logger.log("Recovery_Data sheet not found");
    return createSuccessResponse([]);
  }
  
    const recoveryData = sheet.getDataRange().getValues();
    
    // Extract payer names first
    let payerNames = [];
    let payerIdToName = {};
    
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      if (row.length >= 2 && row[0] === 'Payers') {
        const payersList = row[1].split(',');
        for (let j = 0; j < payersList.length; j++) {
          // PayerID is 1-based, so j+1
          const payerName = payersList[j].trim();
          payerIdToName[j + 1] = payerName;
          payerNames.push(payerName);
        }
      break;
    }
  }
  
    if (payerNames.length === 0) {
      Logger.log("No payers found in Recovery_Data");
      return createSuccessResponse([]);
    }
    
    // Create a map to hold payer monthly data
    const payerMonthlyData = {};
    
    // Initialize the map for each payer
    for (const payer of payerNames) {
      payerMonthlyData[payer] = {
        total: 0.0,
        months: Array(12).fill(0.0) // One entry per month (Jan-Dec)
      };
    }
    
    // Process transactions to populate the monthly data
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      if (row.length >= 2 && row[0] === 'Transactions') {
        try {
          // Transaction format in Recovery_Data: ID|PayerID|Amount|Type|Category|Date
          const parts = row[1].split('|');
          if (parts.length >= 6) {
            // Only process income transactions
            if (parts[3] === 'TxnTyp.inc') {
              // Get payer ID, amount and date
              const payerId = parseInt(parts[1]);
              if (isNaN(payerId)) continue;
              
              const payerName = payerIdToName[payerId] || 'Unknown';
              const amount = parseFloat(parts[2]);
              if (isNaN(amount)) continue;
              
              // Parse the date to get year and month
              try {
                const dateStr = parts[5];
                let date;
                
                if (dateStr.includes('T')) {
                  // ISO 8601 format
                  date = new Date(dateStr);
                } else if (dateStr.includes('/')) {
                  // DD/MM/YYYY format
                  const dateParts = dateStr.split('/');
                  date = new Date(
                    parseInt(dateParts[2]), // year
                    parseInt(dateParts[1]) - 1, // month (0-based)
                    parseInt(dateParts[0]) // day
                  );
                } else {
                  continue; // Skip invalid dates
                }
                
                // Only include transactions for the requested year
                if (date.getFullYear() === year) {
                  const monthIndex = date.getMonth(); // 0-based month index
                  
                  if (payerMonthlyData[payerName]) {
                    // Update total amount
                    payerMonthlyData[payerName].total += amount;
                    
                    // Update month amount
                    payerMonthlyData[payerName].months[monthIndex] += amount;
                  }
                }
              } catch (e) {
                Logger.log("Error parsing date: " + e.toString());
                continue;
              }
            }
          }
        } catch (e) {
          Logger.log("Error processing transaction: " + e.toString());
        }
      }
    }
    
    // Convert to the expected output format for FundData_<year> compatibility
    const result = [];
    let serialNo = 1;
    
    for (const payerName of payerNames) {
      if (payerMonthlyData[payerName]) {
        const data = payerMonthlyData[payerName];
        
        // Create row in format expected by app:
        // [S.No., "Payer Name", Total, Jan, Feb, ..., Dec]
        const row = [
          serialNo++,      // Serial number
          payerName,       // Payer name
          data.total,      // Total amount
        ];
        
        // Add monthly amounts
        for (let i = 0; i < 12; i++) {
          row.push(data.months[i]);
        }
        
        result.push(row);
      }
    }
    
    Logger.log("Successfully extracted payer data for year " + year + " from Recovery_Data. Rows: " + result.length);
    return createSuccessResponse(result);
  } catch (error) {
    Logger.log("Error in getPayerDataForYear: " + error.toString());
    return createErrorResponse(error.toString());
  }
}

// Get payer data for current year
function getPayerData(spreadsheetId, year) {
  return getPayerDataForYear(spreadsheetId, year);
}

// Get payer data for all years
function getAllYearsPayerData(spreadsheetId) {
  try {
    Logger.log("Getting all years payer data from Recovery_Data sheet");
    
    // Get the current year
  const currentYear = new Date().getFullYear();
  const allYearsData = [];
  
    // Process the last 5 years
  for (let year = currentYear; year >= currentYear - 4; year--) {
      const yearDataResponse = getPayerDataForYear(spreadsheetId, year);
      if (yearDataResponse.success && yearDataResponse.data.length > 0) {
        allYearsData.push(...yearDataResponse.data);
      }
    }
    
    Logger.log("Successfully retrieved all years payer data. Rows: " + allYearsData.length);
  return createSuccessResponse(allYearsData);
  } catch (error) {
    Logger.log("Error in getAllYearsPayerData: " + error.toString());
    return createErrorResponse(error.toString());
  }
}

// Get recovery data for restoration
function getRecoveryDataForRestoration(spreadsheetId) {
  try {
    Logger.log("Getting recovery data for restoration from: " + spreadsheetId);
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = spreadsheet.getSheetByName('Recovery_Data');
    
    if (!sheet) {
      Logger.log("Recovery_Data sheet not found");
      return createErrorResponse("Recovery_Data sheet not found in the spreadsheet");
    }
    
    const data = sheet.getDataRange().getValues();
    Logger.log("Successfully retrieved recovery data, rows: " + data.length);
    return createSuccessResponse(data);
  } catch (error) {
    Logger.log("Error in getRecoveryDataForRestoration: " + error.toString());
    return createErrorResponse("Error getting recovery data: " + error.toString());
  }
}

// Create a new spreadsheet for a mosque
function createNewSpreadsheet(mosqueName, email) {
  try {
    Logger.log("Creating new spreadsheet for mosque: " + mosqueName);
    
    // Check if mosqueName is provided
    if (!mosqueName) {
      return createErrorResponse('Mosque name is required to create a spreadsheet');
    }
    
    // Create a new spreadsheet with appropriate title
    let newSpreadsheet = SpreadsheetApp.create(mosqueName + " - Mosque Management");
    let spreadsheetId = newSpreadsheet.getId();
    
    // Check if the spreadsheet ID contains underscores, and regenerate if needed
    let attempts = 0;
    const maxAttempts = 3;
    
    while (spreadsheetId.includes('_') && attempts < maxAttempts) {
      Logger.log("Generated spreadsheet ID contains underscores: " + spreadsheetId + ". Regenerating...");
      
      // Delete the previous spreadsheet with underscore
      try {
        DriveApp.getFileById(spreadsheetId).setTrashed(true);
        Logger.log("Deleted spreadsheet with underscore: " + spreadsheetId);
      } catch (deleteError) {
        Logger.log("Warning: Could not delete previous spreadsheet: " + deleteError.toString());
      }
      
      // Create a new one
      const regeneratedSpreadsheet = SpreadsheetApp.create(mosqueName + " - Mosque Management " + (new Date()).getTime());
      spreadsheetId = regeneratedSpreadsheet.getId();
      newSpreadsheet = regeneratedSpreadsheet;
      
      attempts++;
      Logger.log("Regenerated spreadsheet ID (attempt " + attempts + "): " + spreadsheetId);
    }
    
    if (spreadsheetId.includes('_')) {
      Logger.log("Warning: Could not create spreadsheet without underscores after " + maxAttempts + " attempts");
    }
    
    // Create basic sheets
    try {
      // Removed Transactions, Deductions, and FundData sheets since we're only using Recovery_Data and Summary
      newSpreadsheet.insertSheet('Summary');
      newSpreadsheet.insertSheet('Recovery_Data');
      
      // Delete Sheet1 if it exists
      const sheet1 = newSpreadsheet.getSheetByName('Sheet1');
      if (sheet1) {
        newSpreadsheet.deleteSheet(sheet1);
      }
    } catch (sheetError) {
      Logger.log("Warning: Error while creating sheets: " + sheetError.toString());
      // Continue with the process even if there's an error with sheets
    }
    
    // Share the spreadsheet with the user
    try {
      // Get the associated Drive file
      const file = DriveApp.getFileById(spreadsheetId);
      
      // Share with default user email (hardcoded for now)
      const userEmail = "ajaj42699@gmail.com";
      Logger.log("Sharing spreadsheet with user: " + userEmail);
      
      // Share with editor permission
      file.addEditor(userEmail);
      Logger.log("Successfully shared spreadsheet with: " + userEmail);
      
      // You can also check if email parameter was provided in the request
      if (email) {
        Logger.log("Additional email provided in request: " + email);
        if (email !== userEmail) {
          file.addEditor(email);
          Logger.log("Also shared with: " + email);
        }
      }
    } catch (shareError) {
      Logger.log("Warning: Could not share spreadsheet: " + shareError.toString());
      // Don't fail the whole operation if sharing fails
    }
    
    Logger.log("Successfully created new spreadsheet with ID: " + spreadsheetId);
    return {
      success: true,
      spreadsheetId: spreadsheetId,
      spreadsheetUrl: newSpreadsheet.getUrl()
    };
  } catch (error) {
    Logger.log("Error in createNewSpreadsheet: " + error.toString());
    return createErrorResponse("Error creating new spreadsheet: " + error.toString());
  }
}

// Create recovery data in the spreadsheet
function saveRecoveryData(spreadsheetId, recoveryData) {
  try {
    Logger.log("Saving recovery data to spreadsheet: " + spreadsheetId);
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    let sheet = spreadsheet.getSheetByName('Recovery_Data');
    
    if (!sheet) {
      Logger.log("Recovery_Data sheet not found, creating it");
      sheet = spreadsheet.insertSheet('Recovery_Data');
      if (!sheet) {
        return createErrorResponse("Failed to create Recovery_Data sheet");
      }
    }
    
    // Clear existing recovery data
    sheet.clear();
    
    // Verify the data format has exactly 2 columns
    const validData = [];
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      // Make sure we have exactly 2 columns per row
      if (row.length >= 2) {
        validData.push([row[0], row[1]]);
      } else if (row.length === 1) {
        validData.push([row[0], ""]);
      } else {
        // Skip empty rows
        continue;
      }
    }
    
    // If we have valid data, write it to the sheet
    if (validData.length > 0) {
      sheet.getRange(1, 1, validData.length, 2).setValues(validData);
    }
    
    Logger.log("Successfully saved recovery data");
    return {
      success: true,
      message: "Recovery data saved successfully"
    };
  } catch (error) {
    Logger.log("Error in saveRecoveryData: " + error.toString());
    return createErrorResponse("Error saving recovery data: " + error.toString());
  }
}

// Export data to a specific sheet in the spreadsheet
function exportData(spreadsheetId, sheetName, data) {
  try {
    Logger.log("Exporting data to spreadsheet: " + spreadsheetId);
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    let sheet = spreadsheet.getSheetByName(sheetName);
    
    if (!sheet) {
      Logger.log("Sheet not found: " + sheetName + ", creating it");
      sheet = spreadsheet.insertSheet(sheetName);
      if (!sheet) {
        return createErrorResponse("Failed to create sheet: " + sheetName);
      }
    }
    
    // Clear existing data in the sheet
    sheet.clear();
    
    // Write new data to the sheet
    if (data && data.length > 0) {
      sheet.getRange(1, 1, data.length, data[0].length).setValues(data);
    }
    
    Logger.log("Successfully exported data to sheet: " + sheetName);
    return createSuccessResponse({ message: "Data exported successfully" });
  } catch (error) {
    Logger.log("Error in exportData: " + error.toString());
    return createErrorResponse("Error exporting data: " + error.toString());
  }
}

// Create a sheet if it doesn't exist
function createSheetIfNotExists(spreadsheetId, sheetName) {
  try {
    Logger.log("Creating sheet if not exists: " + sheetName + " in spreadsheet: " + spreadsheetId);
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    let sheet = spreadsheet.getSheetByName(sheetName);
    
    if (!sheet) {
      Logger.log("Sheet not found: " + sheetName + ", creating it");
      sheet = spreadsheet.insertSheet(sheetName);
      if (!sheet) {
        return createErrorResponse("Failed to create sheet: " + sheetName);
      }
      Logger.log("Successfully created sheet: " + sheetName);
    } else {
      Logger.log("Sheet already exists: " + sheetName);
    }
    
    return createSuccessResponse({ 
      message: "Sheet " + sheetName + " created or already exists",
      sheetExists: true
    });
  } catch (error) {
    Logger.log("Error in createSheetIfNotExists: " + error.toString());
    return createErrorResponse("Error creating sheet: " + error.toString());
  }
}

// Get all transactions for a specific payer
function getPayerTransactions(spreadsheetId, payerName) {
  try {
    Logger.log("Getting all transactions for payer: " + payerName + " from Recovery_Data sheet");
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = spreadsheet.getSheetByName('Recovery_Data');
    
    if (!sheet) {
      Logger.log("Recovery_Data sheet not found");
      return createErrorResponse("Recovery_Data sheet not found in the spreadsheet");
    }
    
    const recoveryData = sheet.getDataRange().getValues();
    
    // Extract payer names first
    let payerNames = [];
    let payerIdByName = {};
    
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      if (row.length >= 2 && row[0] === 'Payers') {
        const payersList = row[1].split(',');
        for (let j = 0; j < payersList.length; j++) {
          // PayerID is 1-based, so j+1
          const currentPayerName = payersList[j].trim();
          payerNames.push(currentPayerName);
          payerIdByName[currentPayerName] = j + 1;
        }
        break;
      }
    }
    
    if (payerNames.length === 0) {
      Logger.log("No payers found in Recovery_Data");
      return createSuccessResponse([]);
    }
    
    // Get payer ID for requested payer
    const payerId = payerIdByName[payerName];
    if (!payerId) {
      Logger.log("Payer not found: " + payerName);
      return createSuccessResponse([]);
    }
    
    // Process transactions to find ones for this payer
    const transactions = [];
    
    for (let i = 0; i < recoveryData.length; i++) {
      const row = recoveryData[i];
      if (row.length >= 2 && row[0] === 'Transactions') {
        try {
          // Transaction format in Recovery_Data: ID|PayerID|Amount|Type|Category|Date
          const parts = row[1].split('|');
          if (parts.length >= 6) {
            // Only process income transactions for the specified payer
            if (parts[3] === 'TxnTyp.inc' && parseInt(parts[1]) === payerId) {
              const amount = parseFloat(parts[2]);
              let date;
              
              // Parse the date
              try {
                const dateStr = parts[5];
                
                if (dateStr.includes('T')) {
                  // ISO 8601 format
                  date = new Date(dateStr);
                } else if (dateStr.includes('/')) {
                  // DD/MM/YYYY format
                  const dateParts = dateStr.split('/');
                  date = new Date(
                    parseInt(dateParts[2]), // year
                    parseInt(dateParts[1]) - 1, // month (0-based)
                    parseInt(dateParts[0]) // day
                  );
                } else {
                  continue; // Skip invalid dates
                }
                
                // Add transaction to list
                transactions.push({
                  month: date.getMonth(),
                  monthName: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][date.getMonth()],
                  amount: parseFloat(amount.toFixed(1)), // Ensure it's a float/double with at least one decimal place
                  year: date.getFullYear(),
                  date: date.toISOString()
                });
              } catch (e) {
                Logger.log("Error parsing date: " + e.toString());
                continue;
              }
            }
          }
        } catch (e) {
          Logger.log("Error processing transaction: " + e.toString());
        }
      }
    }
    
    // Sort transactions by date (newest first)
    transactions.sort((a, b) => new Date(b.date) - new Date(a.date));
    
    Logger.log("Successfully retrieved " + transactions.length + " transactions for payer: " + payerName);
    return createSuccessResponse(transactions);
  } catch (error) {
    Logger.log("Error in getPayerTransactions: " + error.toString());
    return createErrorResponse(error.toString());
  }
}
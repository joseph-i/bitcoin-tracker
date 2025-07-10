package main

import (
	"database/sql"  // Package for database operations
	"encoding/json" // Package for JSON parsing
	"fmt"           // Package for formatted I/O operations
	"io"            // Package for I/O primitives
	"log"           // Package for logging
	"net/http"      // Package for HTTP client operations
	"os"            // Package for environment variables and OS operations
	"time"          // Package for time operations and scheduling

	// PostgreSQL driver - this import registers the postgres driver with database/sql
	// The underscore import means we're only importing for side effects (driver registration)
	_ "github.com/lib/pq"
)

// BitcoinPrice represents the structure of the JSON response from CoinGecko API
// This struct maps to the JSON format: {"bitcoin": {"usd": 43250.75}}
type BitcoinPrice struct {
	Bitcoin struct {
		USD float64 `json:"usd"` // The Bitcoin price in USD
	} `json:"bitcoin"`
}

// PriceRecord represents a price record in our database
// This struct maps to our database table structure
type PriceRecord struct {
	ID        int       `json:"id"`        // Primary key (auto-increment)
	Price     float64   `json:"price"`     // Bitcoin price in USD
	Timestamp time.Time `json:"timestamp"` // When the price was recorded
}

// Database connection pool - global variable for database access
// sql.DB represents a pool of database connections, not a single connection
var db *sql.DB

// initDatabase initializes the database connection and creates the table if it doesn't exist
func initDatabase() error {
	// Get database connection string from environment variable
	// Default to a local PostgreSQL instance if not set
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		// Default connection string for local development
		dbURL = "postgres://bitcoin_user:bitcoin_pass@localhost/bitcoin_db?sslmode=disable"
	}

	// Open database connection
	// sql.Open doesn't actually connect, it just validates the DSN
	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	// Ping the database to verify connection
	// This actually establishes a connection to the database
	if err = db.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	// Set connection pool settings for better performance
	db.SetMaxOpenConns(10)                 // Maximum number of open connections
	db.SetMaxIdleConns(5)                  // Maximum number of idle connections
	db.SetConnMaxLifetime(5 * time.Minute) // Maximum connection lifetime

	// Create the bitcoin_prices table if it doesn't exist
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS bitcoin_prices (
		id SERIAL PRIMARY KEY,              -- Auto-incrementing primary key
		price DECIMAL(15,2) NOT NULL,       -- Bitcoin price with 2 decimal places
		timestamp TIMESTAMP DEFAULT NOW()   -- When the price was recorded
	);
	
	-- Create an index on timestamp for faster queries
	CREATE INDEX IF NOT EXISTS idx_bitcoin_prices_timestamp 
	ON bitcoin_prices(timestamp);
	`

	// Execute the table creation SQL
	// Exec is used for SQL statements that don't return rows
	if _, err = db.Exec(createTableSQL); err != nil {
		return fmt.Errorf("failed to create table: %w", err)
	}

	log.Println("Database initialized successfully")
	return nil
}

// getBitcoinPrice fetches the current Bitcoin price from CoinGecko API
// Same implementation as before but with enhanced error logging
func getBitcoinPrice() (float64, error) {
	// CoinGecko API endpoint
	url := "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"

	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: 30 * time.Second, // Increased timeout for reliability
	}

	// Make the HTTP request
	resp, err := client.Get(url)
	if err != nil {
		return 0, fmt.Errorf("failed to make HTTP request: %w", err)
	}
	defer resp.Body.Close()

	// Check HTTP status
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("API request failed with status: %d", resp.StatusCode)
	}

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, fmt.Errorf("failed to read response body: %w", err)
	}

	// Parse JSON response
	var priceData BitcoinPrice
	if err := json.Unmarshal(body, &priceData); err != nil {
		return 0, fmt.Errorf("failed to parse JSON response: %w", err)
	}

	// Validate that we got a valid price
	if priceData.Bitcoin.USD <= 0 {
		return 0, fmt.Errorf("invalid price received: %f", priceData.Bitcoin.USD)
	}

	return priceData.Bitcoin.USD, nil
}

// savePriceToDatabase saves a Bitcoin price to the database
func savePriceToDatabase(price float64) error {
	// SQL query to insert a new price record
	// $1 is a placeholder for the price parameter (PostgreSQL syntax)
	query := `INSERT INTO bitcoin_prices (price) VALUES ($1) RETURNING id`

	// Execute the query and get the generated ID
	// QueryRow is used for queries that return a single row
	var id int
	err := db.QueryRow(query, price).Scan(&id)
	if err != nil {
		return fmt.Errorf("failed to save price to database: %w", err)
	}

	log.Printf("Saved price $%.2f to database with ID %d", price, id)
	return nil
}

// getLatestPrices retrieves the most recent price records from the database
func getLatestPrices(limit int) ([]PriceRecord, error) {
	// SQL query to get the latest prices ordered by timestamp
	query := `
	SELECT id, price, timestamp 
	FROM bitcoin_prices 
	ORDER BY timestamp DESC 
	LIMIT $1
	`

	// Execute the query
	// Query is used for SELECT statements that return multiple rows
	rows, err := db.Query(query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query prices: %w", err)
	}
	defer rows.Close() // Always close rows when done

	// Slice to store the results
	var prices []PriceRecord

	// Iterate through the result rows
	// rows.Next() returns true if there's another row to process
	for rows.Next() {
		var record PriceRecord
		// Scan copies the column values into the struct fields
		err := rows.Scan(&record.ID, &record.Price, &record.Timestamp)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		prices = append(prices, record) // Add record to slice
	}

	// Check for any errors that occurred during iteration
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("row iteration error: %w", err)
	}

	return prices, nil
}

// fetchAndSavePrice fetches the current Bitcoin price and saves it to the database
func fetchAndSavePrice() error {
	log.Println("Fetching Bitcoin price...")

	// Get current price from API
	price, err := getBitcoinPrice()
	if err != nil {
		return fmt.Errorf("failed to fetch Bitcoin price: %w", err)
	}

	// Save price to database
	if err := savePriceToDatabase(price); err != nil {
		return fmt.Errorf("failed to save price: %w", err)
	}

	log.Printf("Successfully recorded Bitcoin price: $%.2f", price)
	return nil
}

// displayLatestPrices shows the most recent price records
func displayLatestPrices() {
	log.Println("Displaying latest price records...")

	// Get the latest 10 price records
	prices, err := getLatestPrices(10)
	if err != nil {
		log.Printf("Error fetching latest prices: %v", err)
		return
	}

	if len(prices) == 0 {
		log.Println("No price records found in database")
		return
	}

	// Display the prices in a formatted table
	fmt.Printf("\n%-5s %-12s %-20s\n", "ID", "Price (USD)", "Timestamp")
	fmt.Println("----------------------------------------")
	for _, record := range prices {
		fmt.Printf("%-5d $%-11.2f %-20s\n",
			record.ID,
			record.Price,
			record.Timestamp.Format("2006-01-02 15:04:05"))
	}
	fmt.Println()
}

// runScheduler runs the price fetching on a schedule
func runScheduler() {
	// Create a ticker that fires every 4 hours
	// time.NewTicker creates a channel that sends the current time every duration
	ticker := time.NewTicker(4 * time.Hour)
	defer ticker.Stop() // Clean up ticker when function exits

	log.Println("Starting Bitcoin price scheduler (every 4 hours)")

	// Fetch price immediately on startup
	if err := fetchAndSavePrice(); err != nil {
		log.Printf("Error on startup fetch: %v", err)
	}

	// Wait for ticker events or shutdown signal
	for {
		select {
		case <-ticker.C: // Ticker channel receives a value every 4 hours
			if err := fetchAndSavePrice(); err != nil {
				log.Printf("Error fetching price: %v", err)
			}
		}
	}
}

// main function - entry point of the application
func main() {
	log.Println("Starting Bitcoin Price Tracker")

	// Initialize database connection
	if err := initDatabase(); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close() // Ensure database connection is closed when program exits

	// Check if we should run in different modes based on command line arguments
	// This allows the same binary to be used for different purposes
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "fetch":
			// One-time fetch mode
			if err := fetchAndSavePrice(); err != nil {
				log.Fatalf("Failed to fetch price: %v", err)
			}
		case "display":
			// Display latest prices mode
			displayLatestPrices()
		case "scheduler":
			// Scheduler mode (default)
			runScheduler()
		default:
			log.Printf("Unknown command: %s", os.Args[1])
			log.Println("Available commands: fetch, display, scheduler")
		}
	} else {
		// Default mode - run scheduler
		runScheduler()
	}
}

.PHONY: help start stop restart status logs clean update-osrm demo

help:
	@echo "OSM Stack - Available Commands"
	@echo ""
	@echo "  make start         - Start all services"
	@echo "  make stop          - Stop all services"
	@echo "  make restart       - Restart all services"
	@echo "  make status        - Check service health"
	@echo "  make logs          - View service logs"
	@echo "  make clean         - Stop and remove all data (WARNING: destructive)"
	@echo "  make update-osrm   - Update OSRM routing data"
	@echo "  make demo          - Open demo page"
	@echo "  make quickstart    - Quick start setup"
	@echo ""

start:
	@echo "Starting OSM stack..."
	docker-compose up -d
	@echo "Services started. Run 'make status' to check health."

stop:
	@echo "Stopping OSM stack..."
	docker-compose stop
	@echo "Services stopped."

restart:
	@echo "Restarting OSM stack..."
	docker-compose restart
	@echo "Services restarted."

status:
	@./scripts/check-status.sh

logs:
	docker-compose logs -f

logs-tile:
	docker-compose logs -f tile-server

logs-nominatim:
	docker-compose logs -f nominatim

logs-osrm:
	docker-compose logs -f osrm

logs-nginx:
	docker-compose logs -f nginx

clean:
	@echo "WARNING: This will delete all imported data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "All data removed."; \
	else \
		echo "Cancelled."; \
	fi

update-osrm:
	@./scripts/update-osrm.sh

demo:
	@echo "Opening demo page..."
	@if command -v open > /dev/null; then \
		open demo.html; \
	elif command -v xdg-open > /dev/null; then \
		xdg-open demo.html; \
	else \
		echo "Please open demo.html in your browser manually"; \
	fi

quickstart:
	@./scripts/quickstart.sh

test:
	@echo "Testing services..."
	@echo ""
	@echo "Testing Nginx..."
	@curl -s http://localhost:8000/health && echo "✓ Nginx OK" || echo "✗ Nginx failed"
	@echo ""
	@echo "Testing Tile Server..."
	@curl -s -o /dev/null http://localhost:8000/tile/0/0/0.png && echo "✓ Tile Server OK" || echo "✗ Tile Server failed"
	@echo ""
	@echo "Testing Nominatim..."
	@curl -s "http://localhost:8000/nominatim/search?q=test&format=json" > /dev/null && echo "✓ Nominatim OK" || echo "✗ Nominatim failed"
	@echo ""
	@echo "Testing OSRM..."
	@curl -s http://localhost:8000/osrm/health > /dev/null && echo "✓ OSRM OK" || echo "✗ OSRM failed"
	@echo ""
